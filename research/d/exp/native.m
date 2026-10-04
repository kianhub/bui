// Native baselines for sdf.bend: the same shading in C (one thread) and as
// Metal compute kernels (leaf-hash kernel for checksum parity, and a
// per-pixel kernel writing a 1920x1080 BGRA-like u32 buffer).
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <time.h>

static double now_us(void) {
  struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
  return ts.tv_sec * 1e6 + ts.tv_nsec / 1e3;
}

#define SHADE_SRC \
"static inline float fmin_(float a, float b) { return a < b ? a : b; }\n" \
"static inline float fmax_(float a, float b) { return a < b ? b : a; }\n" \
"static inline float sat_(float x) { return fmin_(1.0f, fmax_(0.0f, x)); }\n" \
"static inline float sdf_(float px, float py, float cx, float cy, float hw, float hh, float r) {\n" \
"  float qx = fabs(px - cx) - hw + r; float qy = fabs(py - cy) - hh + r;\n" \
"  float ox = fmax_(qx, 0.0f); float oy = fmax_(qy, 0.0f);\n" \
"  return sqrt(ox * ox + oy * oy) + fmin_(fmax_(qx, qy), 0.0f) - r; }\n" \
"static inline float cov_(float d) { return sat_(0.5f - d); }\n" \
"static inline float over_(float d, float s, float a) { return d + (s - d) * a; }\n" \
"static inline uint pack_(float r, float g, float b) {\n" \
"  return ((uint)(255.0f * sat_(r)) << 16) | ((uint)(255.0f * sat_(g)) << 8) | (uint)(255.0f * sat_(b)); }\n" \
"static inline uint shade_(uint x, uint y, float ft) {\n" \
"  float px = (float)x + 0.5f; float py = (float)y + 0.5f;\n" \
"  float a1 = cov_(sdf_(px, py, 480.0f + ft, 300.0f, 400.0f, 220.0f, 16.0f));\n" \
"  float a2 = cov_(sdf_(px, py, 1300.0f, 500.0f + ft, 360.0f, 300.0f, 24.0f));\n" \
"  float a3 = cov_(sdf_(px, py, 960.0f, 900.0f, 800.0f + ft, 80.0f, 40.0f));\n" \
"  float a4 = cov_(sdf_(px, py, 700.0f - ft, 640.0f, 120.0f, 120.0f, 60.0f));\n" \
"  float r = over_(over_(over_(over_(0.10f, 0.90f, a1), 0.20f, a2), 0.95f, a3), 0.40f, a4);\n" \
"  float g = over_(over_(over_(over_(0.11f, 0.90f, a1), 0.50f, a2), 0.60f, a3), 0.80f, a4);\n" \
"  float b = over_(over_(over_(over_(0.13f, 0.92f, a1), 0.90f, a2), 0.20f, a3), 0.40f, a4);\n" \
"  return pack_(r, g, b); }\n"

typedef uint32_t uint;
static inline float fmin_(float a, float b) { return a < b ? a : b; }
static inline float fmax_(float a, float b) { return a < b ? b : a; }
static inline float sat_(float x) { return fmin_(1.0f, fmax_(0.0f, x)); }
static inline float sdf_(float px, float py, float cx, float cy, float hw, float hh, float r) {
  float qx = fabsf(px - cx) - hw + r; float qy = fabsf(py - cy) - hh + r;
  float ox = fmax_(qx, 0.0f); float oy = fmax_(qy, 0.0f);
  return sqrtf(ox * ox + oy * oy) + fmin_(fmax_(qx, qy), 0.0f) - r; }
static inline float cov_(float d) { return sat_(0.5f - d); }
static inline float over_(float d, float s, float a) { return d + (s - d) * a; }
static inline uint pack_(float r, float g, float b) {
  return ((uint)(255.0f * sat_(r)) << 16) | ((uint)(255.0f * sat_(g)) << 8) | (uint)(255.0f * sat_(b)); }
static inline uint shade_(uint x, uint y, float ft) {
  float px = (float)x + 0.5f; float py = (float)y + 0.5f;
  float a1 = cov_(sdf_(px, py, 480.0f + ft, 300.0f, 400.0f, 220.0f, 16.0f));
  float a2 = cov_(sdf_(px, py, 1300.0f, 500.0f + ft, 360.0f, 300.0f, 24.0f));
  float a3 = cov_(sdf_(px, py, 960.0f, 900.0f, 800.0f + ft, 80.0f, 40.0f));
  float a4 = cov_(sdf_(px, py, 700.0f - ft, 640.0f, 120.0f, 120.0f, 60.0f));
  float r = over_(over_(over_(over_(0.10f, 0.90f, a1), 0.20f, a2), 0.95f, a3), 0.40f, a4);
  float g = over_(over_(over_(over_(0.11f, 0.90f, a1), 0.50f, a2), 0.60f, a3), 0.80f, a4);
  float b = over_(over_(over_(over_(0.13f, 0.92f, a1), 0.90f, a2), 0.20f, a3), 0.40f, a4);
  return pack_(r, g, b); }

static uint cpu_frame(float ft) {
  uint total = 0;
  for (uint leaf = 0; leaf < 16384; leaf++) {
    uint acc = 0;
    for (uint k = 0; k < 127; k++) {
      uint i = leaf * 127 + k;
      acc = acc * 31 + shade_(i % 1920, i / 1920, ft);
    }
    total += acc;
  }
  return total;
}

static int cmp(const void* a, const void* b) {
  double x = *(const double*)a, y = *(const double*)b; return x < y ? -1 : x > y;
}

static void stats(const char* name, double* t, int n) {
  qsort(t, n, sizeof *t, cmp);
  printf("%-28s n=%d min=%.0f median=%.0f max=%.0f (us)\n", name, n, t[0], t[n / 2], t[n - 1]);
}

int main(void) {
  @autoreleasepool {
    enum { N = 40 };
    double t[N];
    uint check[N];
    for (int f = 0; f < N; f++) {
      float ft = (float)(N - 1 - f);  // sdf.bend counts p down from 39
      double a = now_us();
      check[f] = cpu_frame(ft);
      t[f] = now_us() - a;
    }
    printf("cpu first sums: %u %u %u\n", check[0], check[1], check[2]);
    stats("C -O3 1 thread", t, N);

    id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
    printf("device: %s\n", dev.name.UTF8String);
    NSString* src = [NSString stringWithFormat:@"#include <metal_stdlib>\nusing namespace metal;\n#pragma clang fp contract(off)\n#define sqrt precise::sqrt\n%s\n"
      "kernel void leaf(device uint* out [[buffer(0)]], constant float& ft [[buffer(1)]], uint leaf [[thread_position_in_grid]]) {\n"
      "  uint acc = 0; for (uint k = 0; k < 127; k++) { uint i = leaf * 127 + k; acc = acc * 31 + shade_(i %% 1920, i / 1920, ft); }\n"
      "  out[leaf] = acc; }\n"
      "kernel void pix(device uint* out [[buffer(0)]], constant float& ft [[buffer(1)]], uint2 p [[thread_position_in_grid]]) {\n"
      "  if (p.x < 1920 && p.y < 1080) out[p.y * 1920 + p.x] = shade_(p.x, p.y, ft); }\n", SHADE_SRC];
    MTLCompileOptions* opts = [MTLCompileOptions new];
    opts.mathMode = MTLMathModeSafe;
    NSError* err = nil;
    id<MTLLibrary> lib = [dev newLibraryWithSource:src options:opts error:&err];
    if (!lib) { printf("compile error: %s\n", err.localizedDescription.UTF8String); return 1; }
    id<MTLComputePipelineState> leaf = [dev newComputePipelineStateWithFunction:[lib newFunctionWithName:@"leaf"] error:&err];
    id<MTLComputePipelineState> pix = [dev newComputePipelineStateWithFunction:[lib newFunctionWithName:@"pix"] error:&err];
    id<MTLCommandQueue> q = [dev newCommandQueue];
    id<MTLBuffer> lbuf = [dev newBufferWithLength:16384 * 4 options:MTLResourceStorageModeShared];
    id<MTLBuffer> pbuf = [dev newBufferWithLength:1920 * 1080 * 4 options:MTLResourceStorageModeShared];

    // empty command buffer round trip
    for (int f = 0; f < N; f++) {
      double a = now_us();
      id<MTLCommandBuffer> cb = [q commandBuffer];
      id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
      [enc endEncoding]; [cb commit]; [cb waitUntilCompleted];
      t[f] = now_us() - a;
    }
    stats("Metal empty cmdbuf+wait", t, N);

    uint gsum[N];
    for (int f = 0; f < N; f++) {
      float ft = (float)(N - 1 - f);
      double a = now_us();
      id<MTLCommandBuffer> cb = [q commandBuffer];
      id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
      [enc setComputePipelineState:leaf]; [enc setBuffer:lbuf offset:0 atIndex:0]; [enc setBytes:&ft length:4 atIndex:1];
      [enc dispatchThreads:MTLSizeMake(16384, 1, 1) threadsPerThreadgroup:MTLSizeMake(256, 1, 1)];
      [enc endEncoding]; [cb commit]; [cb waitUntilCompleted];
      uint s = 0; uint* o = lbuf.contents; for (int i = 0; i < 16384; i++) s += o[i];
      gsum[f] = s;
      t[f] = now_us() - a;
    }
    printf("metal leaf sums: %u %u %u (match cpu: %s)\n", gsum[0], gsum[1], gsum[2],
      memcmp(gsum, check, sizeof gsum) == 0 ? "yes" : "no");
    stats("Metal leaf kernel+wait+sum", t, N);

    double gpu_t[N];
    for (int f = 0; f < N; f++) {
      float ft = (float)(N - 1 - f);
      double a = now_us();
      id<MTLCommandBuffer> cb = [q commandBuffer];
      id<MTLComputeCommandEncoder> enc = [cb computeCommandEncoder];
      [enc setComputePipelineState:pix]; [enc setBuffer:pbuf offset:0 atIndex:0]; [enc setBytes:&ft length:4 atIndex:1];
      [enc dispatchThreads:MTLSizeMake(1920, 1080, 1) threadsPerThreadgroup:MTLSizeMake(32, 8, 1)];
      [enc endEncoding]; [cb commit]; [cb waitUntilCompleted];
      t[f] = now_us() - a;
      gpu_t[f] = (cb.GPUEndTime - cb.GPUStartTime) * 1e6;
    }
    stats("Metal per-pixel 1080p+wait", t, N);
    stats("  (GPU-side time only)", gpu_t, N);
  }
  return 0;
}
