// Cbx: Bend closures applied from inside Cocoa callbacks while Base's
// Window.frame pumps events (window_wait -> sendEvent -> keyDown ->
// interpretKeyEvents -> NSTextInputClient). Re-enters corpus_eval the way
// io_step does (Clo~apply task). Runtime internals: no ABI promise.

#ifdef __OBJC__

#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>
#include <execinfo.h>

static Term             cbx_clo[4];   // f (captures k), g (forks), b (bang), h
static int              cbx_live[4];
static NSMutableString* cbx_log;
static u32              cbx_inserts;
static u32              cbx_hcalls;
static Term             cbx_g2, cbx_b2; // spare copies of g and b for the stress

// Which of our frames are on the stack (static fns may be inlined).
static NSString* cbx_where(void) {
  void* pc[64];
  int   n = backtrace(pc, 64);
  char** s = backtrace_symbols(pc, n);
  NSMutableArray* hit = [NSMutableArray array];
  for (int i = 0; i < n; i += 1) {
    NSString* l = @(s[i]);
    for (NSString* k in @[ @"window_", @"io_step", @"io_loop",
           @"interpretKeyEvents", @"sendEvent", @"TSM", @"NSTextInputContext" ]) {
      if ([l containsString:k]) {
        NSArray* parts = [l componentsSeparatedByString:@" "];
        NSUInteger j = [parts indexOfObjectPassingTest:^BOOL(id o, NSUInteger i, BOOL* st) {
          return [o hasPrefix:@"0x"];
        }];
        NSString* sym = j != NSNotFound && j + 1 < parts.count ? parts[j + 1] : l;
        if (![hit containsObject:sym]) {
          [hit addObject:sym];
        }
        break;
      }
    }
  }
  free(s);
  return [hit componentsJoinedByString:@" < "];
}

static u32 cbx_apply(Term clo, u32 x) {
  Env  e  = { CORPUS, ALC[0] };
  u64  ap = task_node(e, FID(Clo~apply), TERM_HOLE, 0, 0);
  e.mem[ap]     = clo;
  e.mem[ap + 1] = x;
  return (u32)corpus_eval(e.mem, term_tsk(FID(Clo~apply), ap));
}

// A fresh copy of a closure node whose captures are all scalars, so the
// copy can be consumed and the original kept.
static Term cbx_clone(Term clo) {
  Env e   = { CORPUS, ALC[0] };
  u32 f   = (u32)term_aux(clo);
  u32 war = fid_arity(f) - 1;
  u64 a   = term_loc(clo);
  u64 l   = heap_alloc(e, cls_fit(war));
  for (u32 i = 0; i < war; i += 1) {
    e.mem[l + i] = e.mem[a + i];
  }
  return term_clo(f, l);
}

@interface CbxView : NSView <NSTextInputClient>
@end

@implementation CbxView

- (BOOL)acceptsFirstResponder {
  return YES;
}

- (void)keyDown:(NSEvent*)ev {
  [self.superview keyDown:ev];
  [self interpretKeyEvents:@[ ev ]];
}

- (void)keyUp:(NSEvent*)ev {
  [self.superview keyUp:ev];
}

// AppKit's TSM asks this synchronously while handling each key: answer it
// by calling Bend (h, cloned per call so it can run many times).
- (BOOL)hasMarkedText {
  u32 r = cbx_apply(cbx_clone(cbx_clo[3]), cbx_hcalls);
  [cbx_log appendFormat:@"hasMarkedText -> Bend h(%u) = %u\n", cbx_hcalls, r];
  cbx_hcalls += 1;
  return NO;
}

- (NSRange)markedRange {
  return NSMakeRange(NSNotFound, 0);
}

- (NSRange)selectedRange {
  return NSMakeRange(0, 0);
}

- (void)insertText:(id)string replacementRange:(NSRange)repl {
  NSString* s = [string isKindOfClass:NSAttributedString.class]
    ? [string string] : string;
  u32 c = s.length ? [s characterAtIndex:0] : 0;
  u32 i = cbx_inserts++;
  if (i < 3 && cbx_live[i]) {
    cbx_live[i] = 0;
    u32 r = cbx_apply(cbx_clo[i], c);
    const char* nm[] = { "f(x)=2x+k (captures k=1000)",
      "g(x)=x+pow2(16) (65535 forks)", "b(x)=sq!(x) (bang)" };
    [cbx_log appendFormat:@"insertText \"%@\" (%u) -> Bend %s = %u\n   stack: %@\n",
      s, c, nm[i], r, cbx_where()];
  } else {
    u32 r = cbx_apply(cbx_clone(cbx_clo[3]), c);
    [cbx_log appendFormat:@"insertText \"%@\" (%u) -> Bend h(x)=x+7 = %u\n", s, c, r];
  }
  if (i == 4) {
    // stress: many re-entries from this one Cocoa callback
    u32 bad = 0;
    for (u32 k = 0; k < 20000; k += 1) {
      bad += cbx_apply(cbx_clone(cbx_clo[3]), k) != k + 7;
    }
    [cbx_log appendFormat:@"stress h x20000 in insertText: mismatches=%u\n", bad];
    if (cbx_g2) {
      bad = 0;
      for (u32 k = 0; k < 300; k += 1) {
        bad += cbx_apply(cbx_clone(cbx_g2), k) != k + 65536;
      }
      [cbx_log appendFormat:@"stress g (65535 forks) x300: mismatches=%u\n", bad];
      bad = 0;
      for (u32 k = 0; k < 300; k += 1) {
        bad += cbx_apply(cbx_clone(cbx_b2), k) != k * k;
      }
      [cbx_log appendFormat:@"stress b (bang) x300: mismatches=%u\n", bad];
    }
#ifdef CBX_COUNT
    [cbx_log appendFormat:@"cube_run(H, true) calls so far (GPU bangs): %u\n", cbx_bang_gpu];
#endif
  }
}

- (void)setMarkedText:(id)s selectedRange:(NSRange)a replacementRange:(NSRange)b {
}

- (void)unmarkText {
}

- (NSArray*)validAttributesForMarkedText {
  return @[];
}

- (NSAttributedString*)attributedSubstringForProposedRange:(NSRange)r
  actualRange:(NSRangePointer)a {
  return nil;
}

- (NSRect)firstRectForCharacterRange:(NSRange)r actualRange:(NSRangePointer)a {
  return NSZeroRect;
}

- (NSUInteger)characterIndexForPoint:(NSPoint)p {
  return NSNotFound;
}

- (void)doCommandBySelector:(SEL)sel {
}

@end

static void cbx_key(CGKeyCode code, CGEventFlags flags) {
  for (int down = 1; down >= 0; down -= 1) {
    CGEventRef ev = CGEventCreateKeyboardEvent(NULL, code, down);
    CGEventSetFlags(ev, flags);
    [NSApp postEvent:[NSEvent eventWithCGEvent:ev] atStart:NO];
    CFRelease(ev);
  }
}

Term cbx_arm_run(Env e, Term* f, IoWork* w) {
  NSWindow* win  = (__bridge NSWindow*)(void*)io_hand_v(f[0]);
  NSView*   base = win.contentView;
  CbxView*  v    = [[CbxView alloc] initWithFrame:base.bounds];
  [base addSubview:v];
  [win makeFirstResponder:v];
  cbx_log = [NSMutableString string];
  for (int i = 0; i < 4; i += 1) {
    cbx_clo[i]  = f[1 + i];
    cbx_live[i] = 1;
    [cbx_log appendFormat:@"closure %d: tag=%llu rfc=%d fid_arity=%u\n", i,
      (unsigned long long)term_tag(cbx_clo[i]), term_rfc(cbx_clo[i]) ? 1 : 0,
      fid_arity((u32)term_aux(cbx_clo[i]))];
  }
  // g and b capture nothing: keep a spare copy of each for repeated calls
  cbx_g2 = cbx_clone(cbx_clo[1]);
  cbx_b2 = cbx_clone(cbx_clo[2]);
  [cbx_log appendFormat:@"io_gpu=%d pool_size=%ld key=%d\n", (int)io_gpu,
    (long)pool_size, win.isKeyWindow];
  // Shift+A, b, Shift+1, c, d: dispatched by the next Window.frame's pump
  cbx_key(kVK_ANSI_A, kCGEventFlagMaskShift);
  cbx_key(kVK_ANSI_B, 0);
  cbx_key(kVK_ANSI_1, kCGEventFlagMaskShift);
  cbx_key(kVK_ANSI_C, 0);
  cbx_key(kVK_ANSI_D, 0);
  return f[0];
}

Term cbx_take_run(Env e, Term* f, IoWork* w) {
  // drop what was never applied (h always; f/g/b if no key reached them)
  for (int i = 0; i < 4; i += 1) {
    if (i == 3 || cbx_live[i]) {
      term_drop(e, cbx_clo[i]);
    }
  }
  term_drop(e, cbx_g2);
  term_drop(e, cbx_b2);
  [cbx_log appendFormat:@"inserts=%u hasMarkedText calls=%u", cbx_inserts,
    cbx_hcalls];
  const char* s = cbx_log.UTF8String;
  return io_tup(e, f[0], io_str(e, s, strlen(s)));
}

static void __attribute__((constructor)) cbx_use(void) {
  io_eff(CID(Cbx.arm), cbx_arm_run, 0);
  io_eff(CID(Cbx.take), cbx_take_run, 0);
}

#endif
