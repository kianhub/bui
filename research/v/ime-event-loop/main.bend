# Text input and IME for a Bend UI over Base's Window handle, without
# host-to-Bend calls: Bend pushes a snapshot each frame, an Objective-C
# NSTextInputClient overlay answers Cocoa's synchronous queries from it,
# and the edits come back to Bend as events after the frame.
import Base

def Ime.attach(w: Window) -> IO(Window):
  import "./ime.c"
  import "./ime.js"

def Ime.push(w: Window, text: String, caret: U32, mark: U32) -> IO(Window):
  import "./ime.c"
  import "./ime.js"

def Ime.drain(w: Window) -> IO(Window & List<(U32 & U32 & String)>):
  import "./ime.c"
  import "./ime.js"

def Ime.test(w: Window, step: U32) -> IO(Window):
  import "./ime.c"
  import "./ime.js"

# The editor: text before the caret (reversed), after it, and the length
# of the marked run that ends at the caret.
type Ed is Data:
  Ed{before: String, after: String, mark: Nat}

def ed.text(st: Ed) -> String:
  Ed{before, after, mark} = st
  String.append(String.reverse(before), after)

def ed.caret(st: Ed) -> U32:
  Ed{before, after, mark} = st
  U32.from_nat(String.length(before))

def ed.mark(st: Ed) -> U32:
  Ed{before, after, mark} = st
  U32.from_nat(mark)

def ed.cmd(del: Bool, nl: Bool, before: String, after: String) -> Ed:
  match del nl:
    case True{} _:
      Ed{String.drop(before, 1n), after, 0n}
    case False{} True{}:
      Ed{SCon{Chr{10}, before}, after, 0n}
    case False{} False{}:
      Ed{before, after, 0n}

def ed.kind(
  ins: Bool, mk: Bool, un: Bool, before: String, after: String, mark: Nat,
  a: U32, +s: String
) -> Ed:
  match ins mk un:
    case True{} _ _:
      Ed{String.reverse.go(s, String.drop(before, Nat.add(mark, U32.to_nat(a)))), after, 0n}
    case False{} True{} _:
      Ed{String.reverse.go(s, String.drop(before, mark)), after, String.length(s)}
    case False{} False{} True{}:
      Ed{before, after, 0n}
    case False{} False{} False{}:
      ed.cmd(String.eq(s, "deleteBackward:"), String.eq(s, "insertNewline:"),
        before, after)

def ev.name(ins: Bool, mk: Bool, un: Bool) -> String:
  match ins mk un:
    case True{} _ _:
      "insert"
    case False{} True{} _:
      "mark"
    case False{} False{} True{}:
      "unmark"
    case False{} False{} False{}:
      "command"

# One event: Bend's log line for it, and the edit applied.
def ev.line(+k: U32, a: U32, s: String) -> String:
  "bend got: " ++ ev.name(U32.is_eq(k, 1), U32.is_eq(k, 2), U32.is_eq(k, 3))
    ++ " \"" ++ s ++ "\" arg=" ++ U32.show(a) ++ "\n"

def ed.pair(st: Ed, line: String) -> Ed & String:
  (st, line)

def ed.apply3(st: Ed, +k: U32, +a: U32, +s: String) -> Ed & String:
  Ed{before, after, mark} = st
  ed.pair(ed.kind(U32.is_eq(k, 1), U32.is_eq(k, 2), U32.is_eq(k, 3), before,
    after, mark, a, s), ev.line(k, a, s))

def ed.apply(st: Ed, ev: U32 & U32 & String) -> Ed & String:
  (k, a, s) = ev
  ed.apply3(st, k, a, s)

def ed.join(log: String, r: Ed & String) -> Ed & String:
  (st, line) = r
  ed.pair(st, log ++ line)

def ed.step(r: Ed & String, e: U32 & U32 & String) -> Ed & String:
  (st, log) = r
  ed.join(log, ed.apply(st, e))

def ed.apply_all(evs: List<(U32 & U32 & String)>, r: Ed & String) -> Ed & String:
  match evs:
    case Nil{}:
      r
    case e <> rest:
      ed.apply_all(rest, ed.step(r, e))

# Base's own Key events, down only, for contrast (lowercased first char).
def key2(down: Bool, code: U32) -> String:
  match down:
    case True{}:
      " " ++ U32.show(code)
    case False{}:
      ""

def key1(e: Event) -> String:
  match e:
    case Key{code, down}:
      key2(down, code)
    case other:
      ""

def keys(evs: List<Event>) -> String:
  match evs:
    case Nil{}:
      ""
    case e <> rest:
      key1(e) ++ keys(rest)

def done(r: Ed & String, w: Window, rest: Window -> Ed -> IO(Unit)) -> IO(Unit):
  (st, log) = r
  do IO<Unit>:
    u : Unit <- IO.write(log)
    rest(w, st)

def drained(
  st: Ed, r: Window & List<(U32 & U32 & String)>, rest: Window -> Ed -> IO(Unit)
) -> IO(Unit):
  (w, evs) = r
  done(ed.apply_all(evs, ed.pair(st, "")), w, rest)

def framed(
  st: Ed, q: Window & Image & List<Event>, rest: Window -> Ed -> IO(Unit)
) -> IO(Unit):
  (w, im, evs) = q
  do IO<Unit>:
    u : Unit <- IO.print("frame: Base Key codes (down):" ++ keys(evs))
    r : Window & List<(U32 & U32 & String)> <- Ime.drain(w)
    drained(st, r, rest)

def finish(+st: Ed, w: Window) -> IO(Unit):
  do IO<Unit>:
    u : Unit <- IO.print("final Bend text: \"" ++ ed.text(st) ++ "\" caret="
      ++ U32.show(ed.caret(st)) ++ " mark=" ++ U32.show(ed.mark(st)))
    Window.close(w)

def loop(fuel: Nat, +st: Ed, w: Window) -> IO(Unit):
  match fuel:
    case 0n:
      finish(st, w)
    case 1n+(+n):
      do IO<Unit>:
        w1 : Window <- Ime.push(w, ed.text(st), ed.caret(st), ed.mark(st))
        w2 : Window <- Ime.test(w1, U32.from_nat(n))
        q : Window & Image & List<Event> <- Window.frame(w2, Pix{2105376})
        framed(st, q, w3 => s => loop(n, s, w3))

def main() -> IO(Unit):
  do IO<Unit>:
    w : Window <- IO.try(Window, Window.open("ime", 320, 120))
    w1 : Window <- Ime.attach(w)
    loop(14n, Ed{SNil{}, SNil{}, 0n}, w1)
