// Blit.run: the Window.frame present kernel (window_dev from
// bend2/effs/window.c, verbatim MSL) run headless into an offscreen
// 1920x1080 BGRA8 texture; prints the command buffer's GPU time.
#ifdef __OBJC__
#import <Metal/Metal.h>
#endif

#ifdef CID(Blit.run)

#ifdef __OBJC__

#define BL_STR_(x) #x
#define BL_STR(x)  BL_STR_(x)
#define BL_DEF(m)  "#define " #m " " BL_STR(m) "\n"

typedef struct {
  u64 root;
  u32 w;
  u32 h;
  u32 k;
} BlArgs;

static id<MTLDevice>               bl_dev;
static id<MTLCommandQueue>         bl_que;
static id<MTLComputePipelineState> bl_pso;
static id<MTLTexture>              bl_tex;
static id<MTLBuffer>               bl_buf;
static u64                         bl_len;

static const char* bl_msl =
  "#include <metal_stdlib>\n"
  "using namespace metal;\n"
  BL_DEF(TAG_CTR)
  BL_DEF(RFC_BIT)
  BL_DEF(LOC_MASK)
  "struct Args { ulong root; uint w; uint h; uint k; };\n"
  "ulong node(device const ulong* mem, ulong t) {\n"
  "  return t & RFC_BIT ? mem[t & LOC_MASK] >> 24 : t & LOC_MASK;\n"
  "}\n"
  "kernel void blit_dev(device const ulong* mem [[buffer(0)]],\n"
  "  constant Args& a [[buffer(1)]],\n"
  "  texture2d<float, access::write> out [[texture(0)]],\n"
  "  uint2 p [[thread_position_in_grid]]) {\n"
  "  ulong t = a.root;\n"
  "  for (uint i = a.k; ((t >> 56) & 0x7f) == TAG_CTR;) {\n"
  "    uint j = 0;\n"
  "    if (i > 0) {\n"
  "      i -= 1;\n"
  "      j = ((p.y >> i) & 1) * 2 + ((p.x >> i) & 1);\n"
  "    }\n"
  "    t = mem[node(mem, t) + j];\n"
  "  }\n"
  "  float4 c = unpack_unorm4x8_to_float(uint(t & LOC_MASK));\n"
  "  out.write(float4(c.zyx, 1.0), p);\n"
  "}\n";

static void bl_setup(void) {
  if (bl_pso != nil) {
    return;
  }
  bl_dev = gpu_buf != nil ? gpu_dev : MTLCreateSystemDefaultDevice();
  bl_que = [bl_dev newCommandQueue];
  NSError* err = nil;
  id<MTLLibrary> lib = [bl_dev newLibraryWithSource:
    [NSString stringWithUTF8String:bl_msl] options:nil error:&err];
  if (lib == nil) {
    err_fail(err.localizedDescription.UTF8String);
  }
  bl_pso = [bl_dev newComputePipelineStateWithFunction:
    [lib newFunctionWithName:@"blit_dev"] error:&err];
  MTLTextureDescriptor* d = [MTLTextureDescriptor
    texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:1920
    height:1080 mipmapped:NO];
  d.usage = MTLTextureUsageShaderWrite;
  d.storageMode = MTLStorageModePrivate;
  bl_tex = [bl_dev newTextureWithDescriptor:d];
}

static id<MTLBuffer> bl_corpus(Env e) {
  if (gpu_buf != nil) {
    return gpu_buf;
  }
  u64 bump = a32_load(a32_at(e.mem, H_BUMP));
  u64 need = ((HEAP_OFF + (bump << PAGE_BITS)) * 8 + 16383) & ~16383ull;
  if (need > bl_len) {
    u64 most = [bl_dev maxBufferLength] & ~16383ull;
    u64 len = bl_len * 2 > need ? bl_len * 2 : need;
    len = len < most ? len : most;
    bl_buf = [bl_dev newBufferWithBytesNoCopy:e.mem length:len
      options:MTLResourceStorageModeShared
        | MTLResourceHazardTrackingModeUntracked deallocator:nil];
    bl_len = len;
  }
  return bl_buf;
}

Term blit_run_run(Env e, Term* f, IoWork* w) {
  Term image = f[0];
  io_sync();
  bl_setup();
  @autoreleasepool {
    id<MTLBuffer> buf = bl_corpus(e);
    BlArgs args = { image, 1920, 1080, 11 };
    id<MTLCommandBuffer> cb = [bl_que commandBuffer];
    id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
    NSUInteger tw = bl_pso.threadExecutionWidth;
    [enc setComputePipelineState:bl_pso];
    [enc setBuffer:buf offset:0 atIndex:0];
    [enc setBytes:&args length:sizeof(args) atIndex:1];
    [enc setTexture:bl_tex atIndex:0];
    [enc dispatchThreads:MTLSizeMake(1920, 1080, 1)
      threadsPerThreadgroup:MTLSizeMake(tw,
        bl_pso.maxTotalThreadsPerThreadgroup / tw, 1)];
    [enc endEncoding];
    [cb commit];
    [cb waitUntilCompleted];
    fprintf(stderr, "blit_gpu_us %.0f\n", (cb.GPUEndTime - cb.GPUStartTime) * 1e6);
  }
  return image;
}

#else

Term blit_run_run(Env e, Term* f, IoWork* w) {
  return f[0];
}

#endif

static void __attribute__((constructor)) blit_run_use(void) {
  io_eff(CID(Blit.run), blit_run_run, 0);
}

#endif
