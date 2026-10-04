#ifdef __OBJC__

#ifdef CID(Probe.info)
Term probe_info_run(Env e, Term* f, IoWork* w) {
  NSWindow* win = (__bridge NSWindow*)(void*)io_hand_v(f[0]);
  CAMetalLayer* layer = (CAMetalLayer*)win.contentView.layer;
  char buf[256];
  int n = snprintf(buf, sizeof buf,
    "backingScaleFactor %.1f contentsScale %.1f drawableSize %.0fx%.0f bounds %.0fx%.0f resizable %d",
    win.backingScaleFactor, layer.contentsScale, layer.drawableSize.width,
    layer.drawableSize.height, layer.bounds.size.width, layer.bounds.size.height,
    (int)((win.styleMask & NSWindowStyleMaskResizable) != 0));
  return io_tup(e, f[0], io_str(e, buf, (u64)n));
}
static void __attribute__((constructor)) probe_info_use(void) {
  io_eff(CID(Probe.info), probe_info_run, 0);
}
#endif

#ifdef CID(Probe.keys)
// Feeds real layout-translated key events (CGEvent -> NSEvent) and a
// synthetic shift+double-click straight into the BendView handlers.
static void probe_key(NSView* v, CGKeyCode kc, CGEventFlags fl, char* log, size_t cap) {
  CGEventRef ce = CGEventCreateKeyboardEvent(NULL, kc, true);
  CGEventSetFlags(ce, fl);
  NSEvent* ev = [NSEvent eventWithCGEvent:ce];
  CFRelease(ce);
  size_t l = strlen(log);
  snprintf(log + l, cap - l, "[kc %u flags %llx chars '%s' ign '%s'] ", kc,
    (unsigned long long)fl, ev.characters.UTF8String,
    ev.charactersIgnoringModifiers.UTF8String);
  [v keyDown:ev];
}
Term probe_keys_run(Env e, Term* f, IoWork* w) {
  NSWindow* win = (__bridge NSWindow*)(void*)io_hand_v(f[0]);
  NSView* v = win.contentView;
  static char log[2048];
  log[0] = 0;
  probe_key(v, 0, 0, log, sizeof log);                          // a
  probe_key(v, 0, kCGEventFlagMaskShift, log, sizeof log);      // shift+a
  probe_key(v, 18, kCGEventFlagMaskShift, log, sizeof log);     // shift+1
  probe_key(v, 0, kCGEventFlagMaskAlternate, log, sizeof log);  // option+a
  probe_key(v, 0, kCGEventFlagMaskCommand, log, sizeof log);    // cmd+a
  probe_key(v, 126, 0, log, sizeof log);                        // up arrow
  probe_key(v, 36, 0, log, sizeof log);                         // return
  // shift press/release via flagsChanged
  NSEvent* sd = [NSEvent keyEventWithType:NSEventTypeFlagsChanged location:NSZeroPoint
    modifierFlags:NSEventModifierFlagShift timestamp:0 windowNumber:win.windowNumber
    context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:56];
  [v flagsChanged:sd];
  NSEvent* su = [NSEvent keyEventWithType:NSEventTypeFlagsChanged location:NSZeroPoint
    modifierFlags:0 timestamp:0 windowNumber:win.windowNumber
    context:nil characters:@"" charactersIgnoringModifiers:@"" isARepeat:NO keyCode:56];
  [v flagsChanged:su];
  // shift + double click at window point (10, 54) == view (10, 10) in a 64-high flipped view
  NSEvent* md = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:NSMakePoint(10, 54)
    modifierFlags:NSEventModifierFlagShift timestamp:0 windowNumber:win.windowNumber
    context:nil eventNumber:0 clickCount:2 pressure:1];
  [v mouseDown:md];
  // grow the window by 100 points: no event, drawable stays
  [win setContentSize:NSMakeSize(164, 164)];
  return io_tup(e, f[0], io_str(e, log, strlen(log)));
}
static void __attribute__((constructor)) probe_keys_use(void) {
  io_eff(CID(Probe.keys), probe_keys_run, 0);
}
#endif

#endif
