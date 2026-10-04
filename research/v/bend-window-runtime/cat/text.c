#ifdef __OBJC__
// Extends Base's BendView from a user effect: same translation unit, so a
// category can route key-downs through the text system and keep typed text.
static NSMutableString* text_buf;

@interface BendView (Text) <NSTextInputClient>
@end

@implementation BendView (Text)
- (void)keyDown:(NSEvent*)ev {
  [self key:ev down:YES];
  [self interpretKeyEvents:@[ ev ]];
}
- (void)insertText:(id)s replacementRange:(NSRange)r {
  if (text_buf == nil) text_buf = [NSMutableString new];
  [text_buf appendString:[s isKindOfClass:NSAttributedString.class] ? [s string] : s];
}
- (void)doCommandBySelector:(SEL)sel {}
- (void)setMarkedText:(id)s selectedRange:(NSRange)a replacementRange:(NSRange)b {}
- (void)unmarkText {}
- (NSRange)selectedRange { return NSMakeRange(NSNotFound, 0); }
- (NSRange)markedRange { return NSMakeRange(NSNotFound, 0); }
- (BOOL)hasMarkedText { return NO; }
- (NSAttributedString*)attributedSubstringForProposedRange:(NSRange)r actualRange:(NSRangePointer)a { return nil; }
- (NSArray<NSAttributedStringKey>*)validAttributesForMarkedText { return @[]; }
- (NSRect)firstRectForCharacterRange:(NSRange)r actualRange:(NSRangePointer)a { return NSZeroRect; }
- (NSUInteger)characterIndexForPoint:(NSPoint)p { return NSNotFound; }
@end

Term text_feed_run(Env e, Term* f, IoWork* w) {
  NSWindow* win = (__bridge NSWindow*)(void*)io_hand_v(f[0]);
  NSView* v = win.contentView;
  fprintf(stderr, "key %d active %d ctx %p conforms %d\n", (int)win.isKeyWindow, (int)NSApp.isActive, (__bridge void*)v.inputContext, (int)[v conformsToProtocol:@protocol(NSTextInputClient)]);
  [v.inputContext activate];
  CGKeyCode codes[] = { 4, 14, 37, 37, 31 };   // h e l l o on ANSI
  for (int i = 0; i < 5; i += 1) {
    CGEventRef ce = CGEventCreateKeyboardEvent(NULL, codes[i], true);
    CGEventSetFlags(ce, i == 0 ? kCGEventFlagMaskShift : 0);
    [win.contentView keyDown:[NSEvent eventWithCGEvent:ce]];
    CFRelease(ce);
  }
  return f[0];
}
static void __attribute__((constructor)) text_feed_use(void) {
  io_eff(CID(Text.feed), text_feed_run, 0);
}

Term text_take_run(Env e, Term* f, IoWork* w) {
  const char* s = text_buf ? text_buf.UTF8String : "";
  Term r = io_tup(e, f[0], io_str(e, s, strlen(s)));
  text_buf = nil;
  return r;
}
static void __attribute__((constructor)) text_take_use(void) {
  io_eff(CID(Text.take), text_take_run, 0);
}
#endif
