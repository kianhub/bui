// Text.shape(text, size, width) -> IO(List<&2, U32>)
// The String crosses as UTF-8 (io_cstr walks and frees the cons list), becomes
// a CFString (UTF-16 inside CoreText), is laid out with a CTTypesetter that
// breaks lines at `width` points (Helvetica at `size`), and every glyph comes
// back as 4 U32s: glyph id, x (1/64 pt), line index, advance (1/64 pt).
// Prints C-side timings to stderr: ct cstr_us A shape_us B list_us C glyphs G lines L
#import <CoreText/CoreText.h>
#include <mach/mach_time.h>

#ifdef CID(Text.shape)

static mach_timebase_info_data_t ct_tb;
static double ct_us(u64 a, u64 b) {
  return (double)(b - a) * ct_tb.numer / ct_tb.denom / 1000.0;
}
static CTFontRef ct_font;
static double    ct_size;

Term text_shape_run(Env e, Term* f, IoWork* w) {
  if (ct_tb.denom == 0) {
    mach_timebase_info(&ct_tb);
  }
  u64 t0 = mach_absolute_time();
  u64   n    = 0;
  char* text = io_cstr(e, f[0], &n);
  double size = (double)(u32)f[1];
  double width = (double)(u32)f[2];
  u64 t1 = mach_absolute_time();
  if (ct_font == NULL || ct_size != size) {
    if (ct_font) { CFRelease(ct_font); }
    ct_font = CTFontCreateWithName(CFSTR("Helvetica"), size, NULL);
    ct_size = size;
  }
  CFStringRef str = CFStringCreateWithBytes(NULL, (const UInt8*)text, (CFIndex)n,
    kCFStringEncodingUTF8, false);
  CFStringRef keys[] = { kCTFontAttributeName };
  CFTypeRef   vals[] = { ct_font };
  CFDictionaryRef attrs = CFDictionaryCreate(NULL, (const void**)keys,
    (const void**)vals, 1, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
  CFAttributedStringRef as = CFAttributedStringCreate(NULL, str, attrs);
  CTTypesetterRef ts = CTTypesetterCreateWithAttributedString(as);
  CFIndex len = CFStringGetLength(str);
  u32 cap = 4096, cnt = 0, lines = 0;
  u32* out = malloc(cap * 4);
  for (CFIndex at = 0; at < len; lines += 1) {
    CFIndex k = CTTypesetterSuggestLineBreak(ts, at, width);
    if (k <= 0) { k = 1; }
    CTLineRef line = CTTypesetterCreateLine(ts, CFRangeMake(at, k));
    CFArrayRef runs = CTLineGetGlyphRuns(line);
    for (CFIndex r = 0; r < CFArrayGetCount(runs); r += 1) {
      CTRunRef run = CFArrayGetValueAtIndex(runs, r);
      CFIndex gn = CTRunGetGlyphCount(run);
      CGGlyph gl[gn > 0 ? gn : 1];
      CGPoint ps[gn > 0 ? gn : 1];
      CGSize  ad[gn > 0 ? gn : 1];
      CTRunGetGlyphs(run, CFRangeMake(0, 0), gl);
      CTRunGetPositions(run, CFRangeMake(0, 0), ps);
      CTRunGetAdvances(run, CFRangeMake(0, 0), ad);
      for (CFIndex i = 0; i < gn; i += 1) {
        if (cnt + 4 > cap) { cap *= 2; out = realloc(out, cap * 4); }
        out[cnt++] = gl[i];
        out[cnt++] = (u32)(ps[i].x * 64.0);
        out[cnt++] = lines;
        out[cnt++] = (u32)(ad[i].width * 64.0);
      }
    }
    CFRelease(line);
    at += k;
  }
  CFRelease(ts);
  CFRelease(as);
  CFRelease(attrs);
  CFRelease(str);
  free(text);
  u64 t2 = mach_absolute_time();
  Term xs = term_pak(CID(Nil), 0);
  for (u32 i = cnt; i > 0; i -= 1) {
    xs = io_node(e, CID(Con), (Term)out[i - 1], xs);
  }
  free(out);
  u64 t3 = mach_absolute_time();
  fprintf(stderr, "ct cstr_us %.1f shape_us %.1f list_us %.1f glyphs %u lines %u bytes %llu\n",
    ct_us(t0, t1), ct_us(t1, t2), ct_us(t2, t3), cnt / 4, lines, (unsigned long long)n);
  return xs;
}

static void __attribute__((constructor)) text_shape_use(void) {
  io_eff(CID(Text.shape), text_shape_run, 0);
}

#endif
