#import <CoreText/CoreText.h>
Term text_width_run(Env e, Term* f, IoWork* w) {
  uint64_t n = 0;
  char* s = io_cstr(e, f[0], &n);
  CFStringRef str = CFStringCreateWithBytes(NULL, (const UInt8*)s, (CFIndex)n, kCFStringEncodingUTF8, false);
  CTFontRef font = CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, (CGFloat)(u32)f[1], NULL);
  CFStringRef keys[1] = { kCTFontAttributeName };
  CFTypeRef vals[1] = { font };
  CFDictionaryRef attrs = CFDictionaryCreate(NULL, (const void**)keys, (const void**)vals, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  CFAttributedStringRef as = CFAttributedStringCreate(NULL, str, attrs);
  CTLineRef line = CTLineCreateWithAttributedString(as);
  double wd = CTLineGetTypographicBounds(line, NULL, NULL, NULL);
  CFRelease(line); CFRelease(as); CFRelease(attrs); CFRelease(font); CFRelease(str); free(s);
  return (Term)(u32)(wd * 100.0);
}
static void __attribute__((constructor)) text_width_use(void) {
  io_eff(CID(Text.width), text_width_run, 0);
}
