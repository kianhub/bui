// P3.wait(win, max_ms, bounded) -> IO(Window & U32)  (repro, item 4b)
// Blocks the IO thread in AppKit's event queue until an event arrives or a
// deadline passes: now + max_ms, or, with bounded != 0, the runtime's soonest
// parked timer (the head of io_park, the same cell io_wait reads) when that
// is sooner. Dispatches every event it dequeues and returns how many.
// Prints to stderr: wait max_ms M bounded B soon_ms S waited_ms W events N
#ifdef __OBJC__
#import <AppKit/AppKit.h>
#endif

#ifdef CID(P3.wait)
#ifdef __OBJC__

Term p3_wait_run(Env e, Term* f, IoWork* w) {
  u32 max_ms  = (u32)f[1];
  u32 bounded = (u32)f[2];
  u64 t0 = io_tick();
  u64 dl = t0 + (u64)max_ms * 1000000ull;
  u64 soon = 0;
  u32 runnable = 0;
  if (bounded != 0 && io_park != NULL) {
    soon = io_park->next->time;
    if (soon != 0 && soon < dl) {
      dl = soon;
    }
  }
  // another task is runnable (a channel send woke it): do not block at all
  if (bounded != 0 && io_runs != NULL) {
    runnable = 1;
    dl = t0;
  }
  u32 n = 0;
  io_sync();
  @autoreleasepool {
    u64 t = io_tick();
    NSDate* until = t >= dl ? NSDate.distantPast
      : [NSDate dateWithTimeIntervalSinceNow:(double)(dl - t) / 1e9];
    NSEvent* ev = [NSApp nextEventMatchingMask:NSEventMaskAny untilDate:until
      inMode:NSDefaultRunLoopMode dequeue:YES];
    while (ev != nil) {
      [NSApp sendEvent:ev];
      n += 1;
      ev = [NSApp nextEventMatchingMask:NSEventMaskAny untilDate:nil
        inMode:NSDefaultRunLoopMode dequeue:YES];
    }
  }
  u64 t1 = io_tick();
  fprintf(stderr, "wait max_ms %u bounded %u soon_ms %.1f runnable %u waited_ms %.2f events %u\n",
    max_ms, bounded, soon ? (double)(soon - t0) / 1e6 : -1.0, runnable, (double)(t1 - t0) / 1e6, n);
  return io_tup(e, f[0], (Term)n);
}

#else

Term p3_wait_run(Env e, Term* f, IoWork* w) {
  return io_tup(e, f[0], (Term)(u32)0);
}

#endif

static void __attribute__((constructor)) p3_wait_use(void) {
  io_eff(CID(P3.wait), p3_wait_run, 0);
}
#endif
