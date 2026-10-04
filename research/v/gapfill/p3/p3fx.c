// P3 probe: a native Metal renderer for ui_common's Scene, reading the Bend
// heap in place. The Scene is two Bend lists (Qs: rounded cards, top-first;
// Gs: 8x16 4-bit glyph sprites, top-first, glyph rows inline). The host walks
// each list once to record its nodes' heap word offsets (4 bytes per
// primitive: the only marshalling); every field is then read by the GPU
// straight out of the Bend heap (the corpus MTLBuffer: gpu_buf when the bang
// runtime is up, else a no-copy wrap of e.mem, as window.c does).
//
// P3.draw(qs, gs, w, h, mode) -> IO(Qs & Gs), the lists handed back.
//   mode 0: render pipeline, instanced quads then instanced glyph sprites,
//           SDF + border in the fragment shader, blend hardware
//           (premultiplied over), back to front.
//   mode 1: compute kernel per pixel, quads only, front to back with bbox
//           reject over the whole list (no binning).
//   mode 2: compute kernel per pixel, glyphs then quads (no binning).
// Target: offscreen w x h BGRA8 texture (headless, like blit.c), or with
// P3_WIN set by P3.present: the Window handle's CAMetalLayer drawable.
// P3_OWNQ=1 forces a private device queue instead of sharing gpu_que.
// Prints per call to stderr:
//   p3 mode M walk_us W encode_us E gpu_us G wall_us T nq NQ ng NG shared S
// P3.dump(k): writes the texture (BGRA) to p3_<k>.raw in the cwd (needs
// P3_CHECK=1 for a shared texture).
#ifdef __OBJC__
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#import <AppKit/AppKit.h>
#endif
#include <mach/mach_time.h>

#if defined(CID(P3.draw)) || defined(CID(P3.present))

#ifdef __OBJC__

#define P3_STR_(x) #x
#define P3_STR(x)  P3_STR_(x)

typedef struct {
  u32 w, h, nq, ng;
  u32 bg;
} P3U;

static id<MTLDevice>               p3_dev;
static id<MTLCommandQueue>         p3_que;
static id<MTLRenderPipelineState>  p3_qpso, p3_gpso;
static id<MTLComputePipelineState> p3_cpso;
static id<MTLTexture>              p3_tex;
static u32                         p3_w, p3_h;
static id<MTLBuffer>               p3_heap;
static u64                         p3_len;
static id<MTLBuffer>               p3_qoff, p3_goff;
static u32                         p3_qcap, p3_gcap;
static bool                        p3_check, p3_shared;
static mach_timebase_info_data_t   p3_tb;

static double p3_us(u64 a, u64 b) {
  return (double)(b - a) * p3_tb.numer / p3_tb.denom / 1000.0;
}

static const char* p3_msl =
  "#include <metal_stdlib>\n"
  "using namespace metal;\n"
  "struct U { uint w; uint h; uint nq; uint ng; uint bg; };\n"
  "static float f32(device const ulong* m, uint o) { return as_type<float>(uint(m[o])); }\n"
  "static float3 rgb(uint c) { return float3((c >> 16) & 255, (c >> 8) & 255, c & 255) / 255.0; }\n"
  "static float sat(float x) { return clamp(x, 0.0, 1.0); }\n"
  "static float rsdf(float2 p, float x0, float y0, float x1, float y1, float r) {\n"
  "  float hw = (x1 - x0) * 0.5, hh = (y1 - y0) * 0.5;\n"
  "  float qx = fabs(p.x - (x0 + hw)) - hw + r, qy = fabs(p.y - (y0 + hh)) - hh + r;\n"
  "  float ox = max(qx, 0.0), oy = max(qy, 0.0);\n"
  "  return precise::sqrt(ox * ox + oy * oy) + min(max(qx, qy), 0.0) - r;\n"
  "}\n"
  "struct QV { float4 pos [[position]]; uint o [[flat]]; };\n"
  // quad: instance iid draws list entry nq-1-iid (bottom first); the box grows 2 px for the AA band
  "vertex QV quad_vs(uint vid [[vertex_id]], uint iid [[instance_id]], device const ulong* m [[buffer(0)]],\n"
  "  device const uint* off [[buffer(1)]], constant U& u [[buffer(2)]]) {\n"
  "  uint o = off[u.nq - 1 - iid];\n"
  "  float x = (vid & 1) ? f32(m, o + 2) + 2.0 : f32(m, o + 0) - 2.0;\n"
  "  float y = (vid & 2) ? f32(m, o + 3) + 2.0 : f32(m, o + 1) - 2.0;\n"
  "  QV v; v.pos = float4(x / u.w * 2.0 - 1.0, 1.0 - y / u.h * 2.0, 0.0, 1.0); v.o = o; return v;\n"
  "}\n"
  "fragment float4 quad_fs(QV in [[stage_in]], device const ulong* m [[buffer(0)]]) {\n"
  "  uint o = in.o;\n"
  "  float d = rsdf(in.pos.xy, f32(m, o), f32(m, o + 1), f32(m, o + 2), f32(m, o + 3), f32(m, o + 4));\n"
  "  float co = sat(0.5 - d), ci = sat(0.5 - (d + f32(m, o + 5)));\n"
  "  float3 c = ci * rgb(uint(m[o + 6])) + (co - ci) * rgb(uint(m[o + 7]));\n"
  "  return float4(c, co);\n"
  "}\n"
  "vertex QV glyph_vs(uint vid [[vertex_id]], uint iid [[instance_id]], device const ulong* m [[buffer(0)]],\n"
  "  device const uint* off [[buffer(1)]], constant U& u [[buffer(2)]]) {\n"
  "  uint o = off[u.ng - 1 - iid];\n"
  "  float x = float(uint(m[o])) + ((vid & 1) ? 8.0 : 0.0);\n"
  "  float y = float(uint(m[o + 1])) + ((vid & 2) ? 16.0 : 0.0);\n"
  "  QV v; v.pos = float4(x / u.w * 2.0 - 1.0, 1.0 - y / u.h * 2.0, 0.0, 1.0); v.o = o; return v;\n"
  "}\n"
  "fragment float4 glyph_fs(QV in [[stage_in]], device const ulong* m [[buffer(0)]]) {\n"
  "  uint o = in.o;\n"
  "  uint dx = uint(in.pos.x) - uint(m[o]), dy = uint(in.pos.y) - uint(m[o + 1]);\n"
  "  float a = float((uint(m[o + 3 + dy]) >> (4 * dx)) & 15) * 0.0666667;\n"
  "  return float4(rgb(uint(m[o + 2])) * a, a);\n"
  "}\n"
  // compute: one thread per pixel, front to back over the lists (top-first), bbox reject, no binning
  "kernel void p3_cs(device const ulong* m [[buffer(0)]], device const uint* qoff [[buffer(1)]],\n"
  "  device const uint* goff [[buffer(2)]], constant U& u [[buffer(3)]], constant uint& gl [[buffer(4)]],\n"
  "  texture2d<float, access::write> out [[texture(0)]], uint2 g [[thread_position_in_grid]]) {\n"
  "  if (g.x >= u.w || g.y >= u.h) { return; }\n"
  "  float2 p = float2(g) + 0.5; float3 c = 0.0; float t = 1.0;\n"
  "  for (uint i = 0; gl != 0 && i < u.ng; i++) {\n"
  "    uint o = goff[i]; uint dx = g.x - uint(m[o]), dy = g.y - uint(m[o + 1]);\n"
  "    if (dx < 8 && dy < 16) { float a = float((uint(m[o + 3 + dy]) >> (4 * dx)) & 15) * 0.0666667 * t;\n"
  "      c += a * rgb(uint(m[o + 2])); t -= a; }\n"
  "  }\n"
  "  for (uint i = 0; i < u.nq && t > 0.001; i++) {\n"
  "    uint o = qoff[i];\n"
  "    float x0 = f32(m, o), y0 = f32(m, o + 1), x1 = f32(m, o + 2), y1 = f32(m, o + 3);\n"
  "    if (p.x < x0 - 1.0 || p.x > x1 + 1.0 || p.y < y0 - 1.0 || p.y > y1 + 1.0) { continue; }\n"
  "    float d = rsdf(p, x0, y0, x1, y1, f32(m, o + 4));\n"
  "    float ao = sat(0.5 - d) * t, ai = sat(0.5 - (d + f32(m, o + 5))) * t;\n"
  "    c += ai * rgb(uint(m[o + 6])) + (ao - ai) * rgb(uint(m[o + 7])); t -= ao;\n"
  "  }\n"
  "  c += t * rgb(u.bg);\n"
  "  out.write(float4(c, 1.0), g);\n"
  "}\n";

static void p3_setup(Env e, u32 w, u32 h) {
  if (p3_dev == nil) {
    mach_timebase_info(&p3_tb);
    p3_check = getenv("P3_CHECK") != NULL;
    bool own = getenv("P3_OWNQ") != NULL;
    p3_shared = gpu_buf != nil && !own;
    p3_dev = p3_shared ? gpu_dev : MTLCreateSystemDefaultDevice();
    p3_que = p3_shared ? gpu_que : [p3_dev newCommandQueue];
    NSError* err = nil;
    id<MTLLibrary> lib = [p3_dev newLibraryWithSource:
      [NSString stringWithUTF8String:p3_msl] options:nil error:&err];
    if (lib == nil) {
      err_fail(err.localizedDescription.UTF8String);
    }
    MTLRenderPipelineDescriptor* d = [MTLRenderPipelineDescriptor new];
    d.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    d.colorAttachments[0].blendingEnabled = YES;
    d.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorOne;
    d.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    d.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    d.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    d.vertexFunction = [lib newFunctionWithName:@"quad_vs"];
    d.fragmentFunction = [lib newFunctionWithName:@"quad_fs"];
    p3_qpso = [p3_dev newRenderPipelineStateWithDescriptor:d error:&err];
    if (p3_qpso == nil) { err_fail(err.localizedDescription.UTF8String); }
    d.vertexFunction = [lib newFunctionWithName:@"glyph_vs"];
    d.fragmentFunction = [lib newFunctionWithName:@"glyph_fs"];
    p3_gpso = [p3_dev newRenderPipelineStateWithDescriptor:d error:&err];
    if (p3_gpso == nil) { err_fail(err.localizedDescription.UTF8String); }
    p3_cpso = [p3_dev newComputePipelineStateWithFunction:
      [lib newFunctionWithName:@"p3_cs"] error:&err];
    if (p3_cpso == nil) { err_fail(err.localizedDescription.UTF8String); }
  }
  if (w > 0 && h > 0 && (p3_tex == nil || p3_w != w || p3_h != h)) {
    MTLTextureDescriptor* d = [MTLTextureDescriptor
      texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:w
      height:h mipmapped:NO];
    d.usage = MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget;
    d.storageMode = p3_check ? MTLStorageModeShared : MTLStorageModePrivate;
    p3_tex = [p3_dev newTextureWithDescriptor:d];
    p3_w = w;
    p3_h = h;
  }
}

static id<MTLBuffer> p3_corpus(Env e) {
  if (p3_shared && gpu_buf != nil) {
    return gpu_buf;
  }
  u64 bump = a32_load(a32_at(e.mem, H_BUMP));
  u64 need = ((HEAP_OFF + (bump << PAGE_BITS)) * 8 + 16383) & ~16383ull;
  if (need > p3_len) {
    u64 most = [p3_dev maxBufferLength] & ~16383ull;
    u64 len = p3_len * 2 > need ? p3_len * 2 : need;
    len = len < most ? len : most;
    p3_heap = [p3_dev newBufferWithBytesNoCopy:e.mem length:len
      options:MTLResourceStorageModeShared
        | MTLResourceHazardTrackingModeUntracked deallocator:nil];
    p3_len = len;
  }
  return p3_heap;
}

// a node's heap word offset, through a refcount redirect cell if sealed
static u64 p3_loc(Env e, Term t) {
  return term_rfc(t) ? (e.mem[term_loc(t)] >> 24) & LOC_MASK : term_loc(t);
}

// walk a top-first list, writing each node's word offset; nxt = field index of the tail
static u32 p3_walk(Env e, Term t, u32 nxt, id<MTLBuffer> __strong* buf, u32* cap) {
  u32 n = 0;
  u32* out = *buf == nil ? NULL : (u32*)[*buf contents];
  while (term_tag(t) == TAG_CTR) {
    if (n == *cap) {
      u32 nc = *cap ? *cap * 2 : 4096;
      id<MTLBuffer> nb = [p3_dev newBufferWithLength:(NSUInteger)nc * 4
        options:MTLResourceStorageModeShared];
      if (n) { memcpy([nb contents], out, (size_t)n * 4); }
      *buf = nb;
      *cap = nc;
      out = (u32*)[nb contents];
    }
    u64 loc = p3_loc(e, t);
    out[n++] = (u32)loc;
    t = e.mem[loc + nxt];
  }
  return n;
}

static void p3_encode(id<MTLCommandBuffer> cb, id<MTLTexture> tex, id<MTLBuffer> heap,
  u32 mode, P3U* u) {
  if (mode == 0) {
    MTLRenderPassDescriptor* rp = [MTLRenderPassDescriptor renderPassDescriptor];
    rp.colorAttachments[0].texture = tex;
    rp.colorAttachments[0].loadAction = MTLLoadActionClear;
    rp.colorAttachments[0].storeAction = MTLStoreActionStore;
    rp.colorAttachments[0].clearColor = MTLClearColorMake(
      ((u->bg >> 16) & 255) / 255.0, ((u->bg >> 8) & 255) / 255.0, (u->bg & 255) / 255.0, 1.0);
    id<MTLRenderCommandEncoder> re = [cb renderCommandEncoderWithDescriptor:rp];
    [re setRenderPipelineState:p3_qpso];
    [re setVertexBuffer:heap offset:0 atIndex:0];
    [re setVertexBuffer:p3_qoff offset:0 atIndex:1];
    [re setVertexBytes:u length:sizeof(*u) atIndex:2];
    [re setFragmentBuffer:heap offset:0 atIndex:0];
    if (u->nq) {
      [re drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4 instanceCount:u->nq];
    }
    if (u->ng) {
      [re setRenderPipelineState:p3_gpso];
      [re setVertexBuffer:p3_goff offset:0 atIndex:1];
      [re drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4 instanceCount:u->ng];
    }
    [re endEncoding];
  } else {
    u32 gl = mode == 2;
    id<MTLComputeCommandEncoder> ce = [cb computeCommandEncoder];
    [ce setComputePipelineState:p3_cpso];
    [ce setBuffer:heap offset:0 atIndex:0];
    [ce setBuffer:p3_qoff offset:0 atIndex:1];
    [ce setBuffer:(p3_goff ? p3_goff : p3_qoff) offset:0 atIndex:2];
    [ce setBytes:u length:sizeof(*u) atIndex:3];
    [ce setBytes:&gl length:4 atIndex:4];
    [ce setTexture:tex atIndex:0];
    NSUInteger tw = p3_cpso.threadExecutionWidth;
    [ce dispatchThreads:MTLSizeMake(u->w, u->h, 1)
      threadsPerThreadgroup:MTLSizeMake(tw, p3_cpso.maxTotalThreadsPerThreadgroup / tw, 1)];
    [ce endEncoding];
  }
}

static Term p3_go(Env e, Term qs, Term gs, u32 w, u32 h, u32 mode, NSWindow* win) {
  u64 t0 = mach_absolute_time();
  io_sync();
  p3_setup(e, w, h);
  @autoreleasepool {
    id<MTLBuffer> heap = p3_corpus(e);
    u32 nq = p3_walk(e, qs, 8, &p3_qoff, &p3_qcap);
    u32 ng = p3_walk(e, gs, 19, &p3_goff, &p3_gcap);
    u64 t1 = mach_absolute_time();
    P3U u = { w, h, nq, ng, 0x191C21 };
    id<MTLCommandBuffer> cb = [p3_que commandBuffer];
    id<CAMetalDrawable> dr = nil;
    id<MTLTexture> tex = p3_tex;
    if (win != nil) {
      NSEvent* ev;
      while ((ev = [NSApp nextEventMatchingMask:NSEventMaskAny untilDate:nil
          inMode:NSDefaultRunLoopMode dequeue:YES]) != nil) {
        [NSApp sendEvent:ev];
      }
      CAMetalLayer* layer = (CAMetalLayer*)win.contentView.layer;
      dr = [layer nextDrawable];
      tex = dr.texture;
      u.w = (u32)tex.width;
      u.h = (u32)tex.height;
    }
    p3_encode(cb, tex, heap, mode, &u);
    if (dr != nil) {
      [cb presentDrawable:dr];
    }
    u64 t2 = mach_absolute_time();
    [cb commit];
    [cb waitUntilCompleted];
    u64 t3 = mach_absolute_time();
    if ([cb error]) {
      err_fail([cb error].localizedDescription.UTF8String);
    }
    fprintf(stderr, "p3 mode %u walk_us %.1f encode_us %.1f gpu_us %.0f wall_us %.0f nq %u ng %u shared %d w %u h %u\n",
      mode, p3_us(t0, t1), p3_us(t1, t2), (cb.GPUEndTime - cb.GPUStartTime) * 1e6,
      p3_us(t0, t3), nq, ng, (int)(heap == gpu_buf && gpu_buf != nil), u.w, u.h);
  }
  return io_tup(e, qs, gs);
}

Term p3_draw_run(Env e, Term* f, IoWork* w) {
  return p3_go(e, f[0], f[1], (u32)f[2], (u32)f[3], (u32)f[4], nil);
}

Term p3_dump_run(Env e, Term* f, IoWork* w) {
  u32 k = (u32)f[0];
  if (!p3_check || p3_tex == nil) {
    return (Term)(u32)0;
  }
  u64 n = (u64)p3_w * p3_h * 4;
  u8* buf = malloc(n);
  [p3_tex getBytes:buf bytesPerRow:(NSUInteger)p3_w * 4 fromRegion:MTLRegionMake2D(0, 0, p3_w, p3_h) mipmapLevel:0];
  char path[64];
  snprintf(path, sizeof path, "p3_%u.raw", k);
  FILE* fp = fopen(path, "wb");
  fwrite(buf, 1, n, fp);
  fclose(fp);
  free(buf);
  return (Term)(u32)1;
}

#ifdef CID(P3.present)
Term p3_present_run(Env e, Term* f, IoWork* w) {
  NSWindow* win = (__bridge NSWindow*)(void*)io_hand_v(f[0]);
  Term r = p3_go(e, f[1], f[2], 0, 0, (u32)f[3], win);
  return io_tup(e, f[0], r);
}
#endif

#else

Term p3_draw_run(Env e, Term* f, IoWork* w) {
  return io_tup(e, f[0], f[1]);
}
Term p3_dump_run(Env e, Term* f, IoWork* w) {
  return (Term)(u32)0;
}

#endif

static void __attribute__((constructor)) p3_draw_use(void) {
#ifdef CID(P3.draw)
  io_eff(CID(P3.draw), p3_draw_run, 0);
#endif
#ifdef CID(P3.dump)
  io_eff(CID(P3.dump), p3_dump_run, 0);
#endif
#ifdef CID(P3.present)
  io_eff(CID(P3.present), p3_present_run, 0);
#endif
}

#endif
