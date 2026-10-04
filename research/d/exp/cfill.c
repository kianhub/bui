#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
static double now_us(void){struct timespec ts; clock_gettime(CLOCK_MONOTONIC,&ts); return ts.tv_sec*1e6+ts.tv_nsec/1e3;}
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


int main(void){
  uint* buf = malloc(2097152*4);
  for (int f=0; f<5; f++){
    double a=now_us();
    for (uint i=0;i<16384*127;i++) buf[i]=shade_(i%1920,i/1920,39.0f);
    double b=now_us();
    uint total=0;
    for (uint leaf=0;leaf<16384;leaf++){uint acc=0; for(uint k=0;k<127;k++) acc=acc*31+buf[leaf*127+k]; total+=acc;}
    double c=now_us();
    uint total2=0;
    for (uint leaf=0;leaf<16384;leaf++){uint acc=0; for(uint k=0;k<127;k++){uint i=leaf*127+k; acc=acc*31+shade_(i%1920,i/1920,39.0f);} total2+=acc;}
    double d=now_us();
    printf("fill_us %.0f hash_us %.0f fused_us %.0f sum %u %u\n", b-a, c-b, d-c, total, total2);
  }
}
