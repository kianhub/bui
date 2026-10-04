// Ime: a text-input shim over Base's Window handle (no new handle type).
//
// Design under test: Bend pushes a snapshot {text, caret, marked run, caret
// rect} before each frame; Cocoa is pumped only inside Window.frame, so every
// NSTextInputClient query lands while this shim holds the latest snapshot.
// Queries are answered from a local copy of that snapshot, which the shim
// also edits optimistically (insertText / setMarkedText / unmarkText /
// commands) so queries that arrive later in the same pump see the edit before
// Bend does. The edits are queued as events and drained by Bend after the
// frame; Bend applies them and pushes the next snapshot, which the shim
// compares with its prediction.
//
// Offsets crossing to Bend are code points (Bend's Char); NSTextInputClient
// speaks UTF-16, so the shim converts.

#ifdef __OBJC__

#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>

#define BIME_NONE 0xFFFFFFFFu

@interface BimeView : NSView <NSTextInputClient>
@end

static BimeView*       bime_view;
static NSMutableString* bime_text;   // predicted document text
static NSRange         bime_sel;     // UTF-16
static NSRange         bime_mark;    // UTF-16, location NSNotFound if none
static NSRect          bime_caret;   // view coordinates (flipped, points)
static NSMutableArray* bime_q;       // queued @[kind, arg, string]
static u32             bime_nq;      // queries answered since last drain
static int             bime_trace = 1;

static void bime_log(const char* fmt, ...) {
  if (!bime_trace) {
    return;
  }
  va_list ap;
  va_start(ap, fmt);
  fputs("  [shim] ", stdout);
  vprintf(fmt, ap);
  fputs("\n", stdout);
  va_end(ap);
}

static NSString* bime_rs(NSRange r) {
  return r.location == NSNotFound ? @"{NotFound}"
    : [NSString stringWithFormat:@"{%lu,%lu}", (unsigned long)r.location,
        (unsigned long)r.length];
}

static NSString* bime_esc(NSString* s) {
  NSMutableString* o = [NSMutableString string];
  for (NSUInteger i = 0; i < s.length; i += 1) {
    unichar c = [s characterAtIndex:i];
    if (c == '\n') {
      [o appendString:@"\\n"];
    } else {
      [o appendFormat:@"%C", c];
    }
  }
  return o;
}

// UTF-16 offset <-> code point offset over the predicted text.
static NSUInteger bime_u16_of_cp(NSString* s, u32 cp) {
  NSUInteger i = 0;
  for (u32 k = 0; k < cp && i < s.length; k += 1) {
    unichar c = [s characterAtIndex:i];
    i += (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length) ? 2 : 1;
  }
  return i;
}

static u32 bime_cp_of_u16(NSString* s, NSUInteger u) {
  u32 k = 0;
  for (NSUInteger i = 0; i < u && i < s.length; k += 1) {
    unichar c = [s characterAtIndex:i];
    i += (c >= 0xD800 && c <= 0xDBFF && i + 1 < s.length) ? 2 : 1;
  }
  return k;
}

static u32 bime_cps(NSString* s) {
  return bime_cp_of_u16(s, s.length);
}

static void bime_push_ev(u32 kind, u32 arg, NSString* s) {
  // copy: AppKit may hand a mutable string it reuses after the call
  [bime_q addObject:@[ @(kind), @(arg), s ? [s copy] : @"" ]];
}

static NSString* bime_plain(id s) {
  return [s isKindOfClass:NSAttributedString.class]
    ? [(NSAttributedString*)s string] : (NSString*)s;
}

static NSRange bime_clamp(NSRange r) {
  NSUInteger n = bime_text.length;
  if (r.location == NSNotFound) {
    return r;
  }
  NSUInteger lo = MIN(r.location, n);
  NSUInteger hi = MIN(r.location + r.length, n);
  return NSMakeRange(lo, hi - lo);
}

@implementation BimeView

- (BOOL)acceptsFirstResponder {
  return YES;
}

- (BOOL)isFlipped {
  return YES;
}

// Mouse goes to Base's BendView underneath, which keeps its Mouse/Move
// events and coordinates (same frame).
- (void)mouseDown:(NSEvent*)ev { [self.superview mouseDown:ev]; }
- (void)mouseUp:(NSEvent*)ev { [self.superview mouseUp:ev]; }
- (void)rightMouseDown:(NSEvent*)ev { [self.superview rightMouseDown:ev]; }
- (void)rightMouseUp:(NSEvent*)ev { [self.superview rightMouseUp:ev]; }
- (void)otherMouseDown:(NSEvent*)ev { [self.superview otherMouseDown:ev]; }
- (void)otherMouseUp:(NSEvent*)ev { [self.superview otherMouseUp:ev]; }
- (void)mouseMoved:(NSEvent*)ev { [self.superview mouseMoved:ev]; }
- (void)mouseDragged:(NSEvent*)ev { [self.superview mouseDragged:ev]; }
- (void)scrollWheel:(NSEvent*)ev { [self.superview scrollWheel:ev]; }
- (void)flagsChanged:(NSEvent*)ev { [self.superview flagsChanged:ev]; }
- (void)keyUp:(NSEvent*)ev { [self.superview keyUp:ev]; }

// Base's Key event still fires (BendView's keyDown:), then the key goes to
// the input context unless it carries Cmd or Ctrl (GPUI's rule: those are
// bindings, not text).
- (void)keyDown:(NSEvent*)ev {
  [self.superview keyDown:ev];
  bime_log("keyDown keyCode=%u mods=0x%lx characters=\"%s\"", ev.keyCode,
    (unsigned long)(ev.modifierFlags & NSEventModifierFlagDeviceIndependentFlagsMask),
    bime_esc(ev.characters).UTF8String);
  if (ev.modifierFlags & (NSEventModifierFlagCommand | NSEventModifierFlagControl)) {
    return;
  }
  [self interpretKeyEvents:@[ ev ]];
}

// NSTextInputClient: queries, answered from the predicted snapshot.

- (BOOL)hasMarkedText {
  bime_nq += 1;
  BOOL r = bime_mark.location != NSNotFound && bime_mark.length > 0;
  bime_log("Q hasMarkedText -> %d", r);
  return r;
}

- (NSRange)markedRange {
  bime_nq += 1;
  bime_log("Q markedRange -> %s", bime_rs(bime_mark).UTF8String);
  return bime_mark;
}

- (NSRange)selectedRange {
  bime_nq += 1;
  bime_log("Q selectedRange -> %s", bime_rs(bime_sel).UTF8String);
  return bime_sel;
}

- (NSArray<NSAttributedStringKey>*)validAttributesForMarkedText {
  return @[];
}

- (NSAttributedString*)attributedSubstringForProposedRange:(NSRange)range
  actualRange:(NSRangePointer)actual {
  bime_nq += 1;
  NSRange r = bime_clamp(range);
  if (r.location == NSNotFound || (r.length == 0 && range.length != 0)) {
    bime_log("Q attributedSubstring %s -> nil", bime_rs(range).UTF8String);
    return nil;
  }
  if (actual != NULL) {
    *actual = r;
  }
  NSString* s = [bime_text substringWithRange:r];
  bime_log("Q attributedSubstring %s -> \"%s\"", bime_rs(range).UTF8String,
    bime_esc(s).UTF8String);
  return [[NSAttributedString alloc] initWithString:s];
}

- (NSRect)firstRectForCharacterRange:(NSRange)range
  actualRange:(NSRangePointer)actual {
  bime_nq += 1;
  NSRect r = bime_caret;
  NSRect s = [self.window convertRectToScreen:[self convertRect:r toView:nil]];
  if (actual != NULL) {
    *actual = range;
  }
  bime_log("Q firstRect %s -> screen (%.0f,%.0f %.0fx%.0f)",
    bime_rs(range).UTF8String, s.origin.x, s.origin.y, s.size.width,
    s.size.height);
  return s;
}

- (NSUInteger)characterIndexForPoint:(NSPoint)p {
  bime_nq += 1;
  bime_log("Q characterIndexForPoint -> NotFound (no layout pushed)");
  return NSNotFound;
}

// NSTextInputClient: edits, applied locally and queued for Bend.

- (void)insertText:(id)string replacementRange:(NSRange)repl {
  NSString* s = bime_plain(string);
  NSRange   target = bime_mark.location != NSNotFound ? bime_mark
    : repl.location != NSNotFound ? bime_clamp(repl) : bime_sel;
  // cps to delete before the caret besides the marked run (Bend's model is a
  // caret, so a replacement must end at the caret)
  u32 back = 0;
  if (bime_mark.location == NSNotFound && repl.location != NSNotFound) {
    back = bime_cps([bime_text substringWithRange:target]);
  }
  bime_log("E insertText \"%s\" replacementRange=%s (target %s)",
    bime_esc(s).UTF8String, bime_rs(repl).UTF8String,
    bime_rs(target).UTF8String);
  [bime_text replaceCharactersInRange:target withString:s];
  bime_sel  = NSMakeRange(target.location + s.length, 0);
  bime_mark = NSMakeRange(NSNotFound, 0);
  bime_push_ev(1, back, s);
}

- (void)setMarkedText:(id)string selectedRange:(NSRange)sel
  replacementRange:(NSRange)repl {
  NSString* s = bime_plain(string);
  NSRange   target = bime_mark.location != NSNotFound ? bime_mark
    : repl.location != NSNotFound ? bime_clamp(repl) : bime_sel;
  bime_log("E setMarkedText \"%s\" selectedRange=%s replacementRange=%s",
    bime_esc(s).UTF8String, bime_rs(sel).UTF8String, bime_rs(repl).UTF8String);
  [bime_text replaceCharactersInRange:target withString:s];
  bime_mark = s.length > 0 ? NSMakeRange(target.location, s.length)
    : NSMakeRange(NSNotFound, 0);
  NSUInteger so = MIN(sel.location, s.length);
  bime_sel = NSMakeRange(target.location + so, MIN(sel.length, s.length - so));
  bime_push_ev(2, bime_cp_of_u16(s, so), s);
}

- (void)unmarkText {
  bime_log("E unmarkText");
  bime_mark = NSMakeRange(NSNotFound, 0);
  bime_push_ev(3, 0, @"");
}

- (void)doCommandBySelector:(SEL)sel {
  NSString* name = NSStringFromSelector(sel);
  bime_log("E doCommandBySelector %s", name.UTF8String);
  if (sel == @selector(deleteBackward:) && bime_sel.length == 0
    && bime_sel.location > 0) {
    NSRange c = [bime_text rangeOfComposedCharacterSequenceAtIndex:
      bime_sel.location - 1];
    [bime_text deleteCharactersInRange:c];
    bime_sel = NSMakeRange(c.location, 0);
  } else if (sel == @selector(insertNewline:)) {
    [bime_text replaceCharactersInRange:bime_sel withString:@"\n"];
    bime_sel = NSMakeRange(bime_sel.location + 1, 0);
  }
  bime_push_ev(4, 0, name);
}

@end

static NSWindow* bime_win(Term t) {
  return (__bridge NSWindow*)(void*)io_hand_v(t);
}

// Ime.attach(w): a full-size transparent NSTextInputClient overlay on Base's
// BendView, made first responder.
Term ime_attach_run(Env e, Term* f, IoWork* w) {
  NSWindow* win  = bime_win(f[0]);
  NSView*   base = win.contentView;
  bime_view = [[BimeView alloc] initWithFrame:base.bounds];
  bime_view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [base addSubview:bime_view];
  BOOL ok = [win makeFirstResponder:bime_view];
  bime_text = [NSMutableString string];
  bime_sel  = NSMakeRange(0, 0);
  bime_mark = NSMakeRange(NSNotFound, 0);
  bime_q    = [NSMutableArray array];
  TISInputSourceRef cur = TISCopyCurrentKeyboardInputSource();
  bime_log("attached: firstResponder=%s ok=%d inputContext=%s layout=%s",
    NSStringFromClass([win.firstResponder class]).UTF8String, ok,
    bime_view.inputContext ? "yes" : "no",
    [(__bridge NSString*)TISGetInputSourceProperty(cur, kTISPropertyInputSourceID) UTF8String]);
  CFRelease(cur);
  return f[0];
}

// Ime.push(w, text, caret, mark): Bend's snapshot. caret and mark are code
// point counts: the caret's offset and the marked run's length ending at it.
Term ime_push_run(Env e, Term* f, IoWork* w) {
  u64   n = 0;
  char* c = io_cstr(e, f[1], &n);
  NSString* text = [[NSString alloc] initWithBytes:c length:n
    encoding:NSUTF8StringEncoding];
  free(c);
  u32 caret = (u32)f[2];
  u32 mark  = (u32)f[3];
  NSUInteger cu = bime_u16_of_cp(text, caret);
  NSUInteger mu = bime_u16_of_cp(text, caret - mark);
  NSRange sel  = NSMakeRange(cu, 0);
  NSRange mr   = mark == 0 ? NSMakeRange(NSNotFound, 0)
    : NSMakeRange(mu, cu - mu);
  BOOL agree = [text isEqualToString:bime_text]
    && NSEqualRanges(sel, bime_sel)
    && (mr.location == NSNotFound ? bime_mark.location == NSNotFound
      : NSEqualRanges(mr, bime_mark));
  bime_log("snapshot from Bend: text=\"%s\" sel=%s mark=%s; shim predicted "
    "\"%s\" sel=%s mark=%s -> %s", bime_esc(text).UTF8String,
    bime_rs(sel).UTF8String, bime_rs(mr).UTF8String,
    bime_esc(bime_text).UTF8String, bime_rs(bime_sel).UTF8String,
    bime_rs(bime_mark).UTF8String, agree ? "AGREE" : "DIFFER");
  [bime_text setString:text];
  bime_sel  = sel;
  bime_mark = mr;
  // fake layout: 9pt advance per code point, one line at y=40
  bime_caret = NSMakeRect(20 + 9.0 * bime_cp_of_u16(text, cu), 40, 1, 18);
  [bime_view.inputContext invalidateCharacterCoordinates];
  NSWindow* win = bime_win(f[0]);
  if (win.firstResponder != bime_view) {
    [win makeFirstResponder:bime_view];
  }
  return f[0];
}

// Ime.drain(w): the queued edits as (kind, arg, text).
Term ime_drain_run(Env e, Term* f, IoWork* w) {
  Term list = term_pak(CID(Nil), 0);
  for (NSInteger i = (NSInteger)bime_q.count - 1; i >= 0; i -= 1) {
    NSArray*    ev = bime_q[i];
    const char* s  = [ev[2] UTF8String];
    Term t = io_tup(e, [ev[0] unsignedIntValue],
      io_tup(e, [ev[1] unsignedIntValue], io_str(e, s, strlen(s))));
    list = io_node(e, CID(Con), t, list);
  }
  bime_log("drain: %lu events, %u queries answered during the pump",
    (unsigned long)bime_q.count, bime_nq);
  [bime_q removeAllObjects];
  bime_nq = 0;
  return io_tup(e, f[0], list);
}

// Self-tests, run before a frame so the posted events are pumped by
// Window.frame like real ones.

static void bime_post_cg(CGKeyCode code, CGEventFlags flags, int pid_mode) {
  for (int down = 1; down >= 0; down -= 1) {
    CGEventRef ev = CGEventCreateKeyboardEvent(NULL, code, down);
    CGEventSetFlags(ev, flags);
    if (pid_mode) {
      CGEventPostToPid(getpid(), ev);
    } else {
      NSEvent* ne = [NSEvent eventWithCGEvent:ev];
      [NSApp postEvent:ne atStart:NO];
    }
    CFRelease(ev);
  }
}

static void bime_q_state(const char* what) {
  NSRange mr = [bime_view markedRange];
  NSRange sr = [bime_view selectedRange];
  NSRange act = NSMakeRange(0, 0);
  NSAttributedString* a = [bime_view
    attributedSubstringForProposedRange:NSMakeRange(0, bime_text.length)
    actualRange:&act];
  NSRect r = [bime_view firstRectForCharacterRange:sr actualRange:NULL];
  (void)a;
  (void)r;
  (void)mr;
  bime_log("-- after %s (no Bend frame yet)", what);
}

Term ime_test_run(Env e, Term* f, IoWork* w) {
  NSWindow* win  = bime_win(f[0]);
  u32       n    = (u32)f[1];
  u32       step = n == 11 ? 1 : n == 9 ? 2 : n == 7 ? 3 : n == 5 ? 4 : 0;
  if (step == 1) {
    bime_log("test 1: NSApp active=%d key=%d firstResponder=%s; posting "
      "CGEvent-built NSEvents into the app queue (German layout keyCodes)",
      NSApp.isActive, win.isKeyWindow,
      NSStringFromClass([win.firstResponder class]).UTF8String);
    // Shift+H a l l o space Shift+W e l t Shift+1 ; Shift+2 Shift+7
    bime_post_cg(kVK_ANSI_H, kCGEventFlagMaskShift, 0);
    bime_post_cg(kVK_ANSI_A, 0, 0);
    bime_post_cg(kVK_ANSI_L, 0, 0);
    bime_post_cg(kVK_ANSI_L, 0, 0);
    bime_post_cg(kVK_ANSI_O, 0, 0);
    bime_post_cg(kVK_Space, 0, 0);
    bime_post_cg(kVK_ANSI_W, kCGEventFlagMaskShift, 0);
    bime_post_cg(kVK_ANSI_E, 0, 0);
    bime_post_cg(kVK_ANSI_L, 0, 0);
    bime_post_cg(kVK_ANSI_T, 0, 0);
    bime_post_cg(kVK_ANSI_1, kCGEventFlagMaskShift, 0);
    bime_post_cg(kVK_ANSI_2, kCGEventFlagMaskShift, 0);
    bime_post_cg(kVK_ANSI_7, kCGEventFlagMaskShift, 0);
    bime_post_cg(kVK_ANSI_Z, 0, 0);            // German: y
    bime_post_cg(kVK_ANSI_Semicolon, 0, 0);    // German: ö
    bime_post_cg(kVK_ANSI_L, kCGEventFlagMaskAlternate, 0); // German: @
    bime_post_cg(kVK_ANSI_S, kCGEventFlagMaskCommand, 0);   // binding, not text
  } else if (step == 2) {
    bime_log("test 2: dead key: German acute (kVK_ANSI_Equal) then e, then "
      "Shift+acute (grave) then Shift+a, then Return and Backspace");
    bime_post_cg(kVK_ANSI_Equal, 0, 0);
    bime_post_cg(kVK_ANSI_E, 0, 0);
    bime_post_cg(kVK_ANSI_Equal, kCGEventFlagMaskShift, 0);
    bime_post_cg(kVK_ANSI_A, kCGEventFlagMaskShift, 0);
    bime_post_cg(kVK_Return, 0, 0);
    bime_post_cg(kVK_ANSI_X, 0, 0);
    bime_post_cg(kVK_Delete, 0, 0);
  } else if (step == 3) {
    bime_log("test 3: an IME's call sequence driven directly on the view "
      "(Japanese-style: k -> か -> かな -> commit 仮名), queries in between");
    [bime_view setMarkedText:@"k" selectedRange:NSMakeRange(1, 0)
      replacementRange:NSMakeRange(NSNotFound, 0)];
    bime_q_state("setMarkedText k");
    [bime_view setMarkedText:@"か" selectedRange:NSMakeRange(1, 0)
      replacementRange:NSMakeRange(NSNotFound, 0)];
    [bime_view setMarkedText:@"かな" selectedRange:NSMakeRange(2, 0)
      replacementRange:NSMakeRange(NSNotFound, 0)];
    bime_q_state("setMarkedText かな");
    [bime_view insertText:@"仮名😀" replacementRange:NSMakeRange(NSNotFound, 0)];
    bime_q_state("insertText 仮名😀");
    // press-and-hold accent menu style: replace the char before the caret
    [bime_view insertText:@"x" replacementRange:NSMakeRange(NSNotFound, 0)];
    NSRange sr = [bime_view selectedRange];
    [bime_view insertText:@"ẍ" replacementRange:NSMakeRange(sr.location - 1, 1)];
    bime_q_state("accent-menu replace x -> ẍ");
  } else if (step == 4) {
    bime_log("test 4: CGEventPostToPid(self) for Shift+q (window-server path)");
    bime_post_cg(kVK_ANSI_Q, kCGEventFlagMaskShift, 1);
  }
  return f[0];
}

static void __attribute__((constructor)) ime_use(void) {
  io_eff(CID(Ime.attach), ime_attach_run, 0);
  io_eff(CID(Ime.push), ime_push_run, 0);
  io_eff(CID(Ime.drain), ime_drain_run, 0);
  io_eff(CID(Ime.test), ime_test_run, 0);
}

#endif
