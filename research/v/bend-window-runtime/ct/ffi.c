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

