// FFI probes
// ==========

#import <CoreText/CoreText.h>

#ifdef CID(Text.width)

Term text_width_run(Env e, Term* f, IoWork* w) {
  u64   n    = 0;
  char* text = io_cstr(e, f[0], &n);
  CTFontRef font = CTFontCreateWithName(CFSTR("Helvetica"), (CGFloat)(u32)f[1], NULL);
  CFStringRef str = CFStringCreateWithBytes(NULL, (const UInt8*)text, (CFIndex)n,
    kCFStringEncodingUTF8, false);
  CFStringRef keys[] = { kCTFontAttributeName };
  CFTypeRef   vals[] = { font };
  CFDictionaryRef attrs = CFDictionaryCreate(NULL, (const void**)keys,
    (const void**)vals, 1, &kCFTypeDictionaryKeyCallBacks,
    &kCFTypeDictionaryValueCallBacks);
  CFAttributedStringRef as = CFAttributedStringCreate(NULL, str, attrs);
  CTLineRef line = CTLineCreateWithAttributedString(as);
  double width = CTLineGetTypographicBounds(line, NULL, NULL, NULL);
  CFRelease(line);
  CFRelease(as);
  CFRelease(attrs);
  CFRelease(str);
  CFRelease(font);
  free(text);
  return (Term)(u32)(width * 1000.0);
}

static void __attribute__((constructor)) text_width_use(void) {
  io_eff(CID(Text.width), text_width_run, 0);
}

#endif

#ifdef CID(Px.sum)

// The array crosses as its term: a BUF of 2^cls u32 words (or an ARR of
// 2^cls Terms), read in place and handed back.
Term px_sum_run(Env e, Term* f, IoWork* w) {
  Term a   = f[0];
  bool arr = term_tag(a) == TAG_ARR;
  u64  loc = blk_loc(e.mem, a);
  u32  n   = 1u << blk_cls(a);
  u32  s   = 0;
  for (u32 i = 0; i < n; i += 1) {
    s += (u32)blk_read(e.mem, arr, loc, i);
  }
  return io_tup(e, a, s);
}

static void __attribute__((constructor)) px_sum_use(void) {
  io_eff(CID(Px.sum), px_sum_run, 0);
}

#endif

#ifdef CID(Nop.call)

Term nop_call_run(Env e, Term* f, IoWork* w) {
  return (Term)(u32)((u32)f[0] + 1);
}

static void __attribute__((constructor)) nop_call_use(void) {
  io_eff(CID(Nop.call), nop_call_run, 0);
}

#endif
