#ifdef __OBJC__

Term win_info_run(Env e, Term* f, IoWork* w) {
  NSWindow* win = (__bridge NSWindow*)(void*)io_hand_v(f[0]);
  CAMetalLayer* layer = (CAMetalLayer*)win.contentView.layer;
  char buf[256];
  int n = snprintf(buf, sizeof buf,
    "backingScaleFactor %.1f contentsScale %.1f drawableSize %.0fx%.0f bounds %.0fx%.0f",
    win.backingScaleFactor, layer.contentsScale, layer.drawableSize.width,
    layer.drawableSize.height, layer.bounds.size.width, layer.bounds.size.height);
  return io_tup(e, f[0], io_str(e, buf, (u64)n));
}

static void __attribute__((constructor)) win_info_use(void) {
  io_eff(CID(Win.info), win_info_run, 0);
}

#endif
