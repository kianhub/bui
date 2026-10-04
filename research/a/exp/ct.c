#import <CoreText/CoreText.h>
#import <CoreGraphics/CoreGraphics.h>
#include <stdio.h>
int main(void) {
  CTFontRef font = CTFontCreateWithName(CFSTR("Helvetica"), 16.0, NULL);
  UniChar ch = 'g'; CGGlyph glyph = 0;
  CTFontGetGlyphsForCharacters(font, &ch, &glyph, 1);
  CGRect r = CTFontGetBoundingRectsForGlyphs(font, kCTFontOrientationDefault, &glyph, NULL, 1);
  int w = 16, h = 20; unsigned char buf[16*20] = {0};
  CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray();
  CGContextRef cx = CGBitmapContextCreate(buf, w, h, 8, w, gray, kCGImageAlphaOnly);
  CGPoint pos = CGPointMake(2, 5);
  CTFontDrawGlyphs(font, &glyph, &pos, 1, cx);
  int lit = 0; for (int i = 0; i < w*h; i++) lit += buf[i] > 0;
  printf("glyph=%u bbox=(%.1f,%.1f,%.1f,%.1f) lit_pixels=%d\n", glyph, r.origin.x, r.origin.y, r.size.width, r.size.height, lit);
  return 0;
}
