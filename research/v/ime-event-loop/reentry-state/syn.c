#ifdef __OBJC__

#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>

static Term             syn_state;   // the editor state, owned by C mid-frame
static Term             syn_step;    // capture-less closure, cloned per call
static NSMutableString* syn_log;

static Term syn_clone(Term clo) {
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

// (state, op, text) -> (state', answer), applied synchronously.
static u32 syn_call(u32 op, NSString* text) {
  Env  e  = { CORPUS, ALC[0] };
  const char* s = text.UTF8String;
  Term arg = io_tup(e, syn_state, io_tup(e, op, io_str(e, s, strlen(s))));
  u64  ap = task_node(e, FID(Clo~apply), TERM_HOLE, 0, 0);
  e.mem[ap]     = syn_clone(syn_step);
  e.mem[ap + 1] = arg;
  Term r = corpus_eval(e.mem, term_tsk(FID(Clo~apply), ap));
  if (term_tag(r) != TAG_CTR || (u32)term_aux(r) != CID(Tuple)) {
    [syn_log appendFormat:@"unexpected result term tag=%llu aux=%u\n",
      (unsigned long long)term_tag(r), (u32)term_aux(r)];
    return 0;
  }
  Term fb[2];
  spare_free(e, cls_fit(2), ctr_take(e, r, 2, fb));
  syn_state = fb[0];
  return (u32)fb[1];
}

@interface SynView : NSView <NSTextInputClient>
@end

@implementation SynView
- (BOOL)acceptsFirstResponder { return YES; }
- (void)keyDown:(NSEvent*)ev {
  [self.superview keyDown:ev];
  [self interpretKeyEvents:@[ ev ]];
}
- (void)keyUp:(NSEvent*)ev { [self.superview keyUp:ev]; }
- (BOOL)hasMarkedText { return NO; }
- (NSRange)markedRange { return NSMakeRange(NSNotFound, 0); }
// the caret is the end of Bend's text: ask Bend now
- (NSRange)selectedRange {
  u32 n = syn_call(0, @"");
  [syn_log appendFormat:@"selectedRange -> Bend says length %u\n", n];
  return NSMakeRange(n, 0);
}
- (void)insertText:(id)string replacementRange:(NSRange)repl {
  NSString* s = [string isKindOfClass:NSAttributedString.class] ? [string string] : string;
  u32 old = syn_call(1, s);
  NSRange sel = [self selectedRange];
  [syn_log appendFormat:@"insertText \"%@\" -> Bend appended (old length %u, caret now %lu)\n",
    s, old, (unsigned long)sel.location];
}
- (void)setMarkedText:(id)s selectedRange:(NSRange)a replacementRange:(NSRange)b {}
- (void)unmarkText {}
- (NSArray*)validAttributesForMarkedText { return @[]; }
- (NSAttributedString*)attributedSubstringForProposedRange:(NSRange)r actualRange:(NSRangePointer)a { return nil; }
- (NSRect)firstRectForCharacterRange:(NSRange)r actualRange:(NSRangePointer)a { return NSZeroRect; }
- (NSUInteger)characterIndexForPoint:(NSPoint)p { return NSNotFound; }
- (void)doCommandBySelector:(SEL)sel {}
@end

static void syn_key(CGKeyCode code, CGEventFlags flags) {
  for (int down = 1; down >= 0; down -= 1) {
    CGEventRef ev = CGEventCreateKeyboardEvent(NULL, code, down);
    CGEventSetFlags(ev, flags);
    [NSApp postEvent:[NSEvent eventWithCGEvent:ev] atStart:NO];
    CFRelease(ev);
  }
}

Term syn_arm_run(Env e, Term* f, IoWork* w) {
  NSWindow* win = (__bridge NSWindow*)(void*)io_hand_v(f[0]);
  SynView*  v   = [[SynView alloc] initWithFrame:win.contentView.bounds];
  [win.contentView addSubview:v];
  [win makeFirstResponder:v];
  syn_state = f[1];
  syn_step  = f[2];
  syn_log   = [NSMutableString string];
  syn_key(kVK_ANSI_H, kCGEventFlagMaskShift);
  syn_key(kVK_ANSI_I, 0);
  syn_key(kVK_ANSI_1, kCGEventFlagMaskShift);
  return f[0];
}

Term syn_take_run(Env e, Term* f, IoWork* w) {
  term_drop(e, syn_step);
  const char* s = syn_log.UTF8String;
  return io_tup(e, f[0], io_tup(e, syn_state, io_str(e, s, strlen(s))));
}

static void __attribute__((constructor)) syn_use(void) {
  io_eff(CID(Syn.arm), syn_arm_run, 0);
  io_eff(CID(Syn.take), syn_take_run, 0);
}

#endif
