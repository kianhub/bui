#!/usr/bin/env python3
"""Patch Bend's emitted C to log every GPU bang and count CPU-pool cube runs.
usage: instr.py in.c out.c
Env at run time: BANG_LOG=1 prints one stderr line per bang:
  bang fid F ar A passes P gpu_us G lag_us L wall_us W at_ms T
  (gpu_us = sum of GPUEndTime-GPUStartTime over the bang's passes;
   lag_us = GPUStartTime - commit time, first pass; wall_us = host wall)
At exit: prof gpu_bangs N cpu_runs M gpu_passes K
"""
import sys, re
src = open(sys.argv[1]).read()

decl = r'''
static u64 io_tick(void);
static u32 prof_passes, prof_gpu_bangs, prof_cpu_runs, prof_all_passes, prof_fid, prof_f;
static double prof_gpu_us, prof_lag_us;
static u64 prof_t0, prof_boot;
static bool prof_log;
static void prof_exit(void) {
  fprintf(stderr, "prof gpu_bangs %u cpu_runs %u gpu_passes %u\n", prof_gpu_bangs, prof_cpu_runs, prof_all_passes);
}
static void __attribute__((constructor)) prof_use(void) {
  prof_log = getenv("BANG_LOG") != NULL;
  atexit(prof_exit);
}
'''
# 1. declarations before gpu_pass (Metal)
anchor = 'static void gpu_pass(u32 f) {\n  @autoreleasepool {'
assert src.count(anchor) == 1, src.count(anchor)
src = src.replace(anchor, decl + anchor)

# 2. per-pass timing inside gpu_pass
old = '''    [cb commit];
    [cb waitUntilCompleted];
    if ([cb error]) {
      gpu_fail([cb error]);
    }'''
assert src.count(old) == 1, src.count(old)
new = '''    double prof_commit = (double)clock_gettime_nsec_np(CLOCK_UPTIME_RAW) / 1e9;
    [cb commit];
    [cb waitUntilCompleted];
    if ([cb error]) {
      gpu_fail([cb error]);
    }
    if (prof_passes == 0) { prof_lag_us = (cb.GPUStartTime - prof_commit) * 1e6; prof_f = f; }
    prof_passes += 1;
    prof_all_passes += 1;
    prof_gpu_us += (cb.GPUEndTime - cb.GPUStartTime) * 1e6;'''
src = src.replace(old, new)

# 3. around cube_run(H, true) in corpus_eval
old = '''        ring_push(H, 0, t);
        cube_run(H, true);'''
assert src.count(old) == 1
new = '''        ring_push(H, 0, t);
        prof_fid = (u32)term_aux(t); prof_passes = 0; prof_gpu_us = 0; prof_lag_us = 0;
        if (prof_boot == 0) { prof_boot = io_tick(); }
        prof_t0 = io_tick();
        cube_run(H, true);
        prof_gpu_bangs += 1;
        if (prof_log) {
          u64 prof_t1 = io_tick();
          fprintf(stderr, "bang fid %u ar %u passes %u gpu_us %.0f lag_us %.0f wall_us %.0f at_ms %.1f f %u\\n",
            prof_fid, fid_arity(prof_fid), prof_passes, prof_gpu_us, prof_lag_us,
            (double)(prof_t1 - prof_t0) / 1e3, (double)(prof_t0 - prof_boot) / 1e6, prof_f);
        }'''
src = src.replace(old, new)

# 4. count CPU cube runs
old = '''    pool_open();
    cube_run(H, false);'''
assert src.count(old) == 1
src = src.replace(old, '''    pool_open();
    prof_cpu_runs += 1;
    cube_run(H, false);''')
open(sys.argv[2], 'w').write(src)
print("patched", sys.argv[2])
