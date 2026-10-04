# Synchronous text input with the app state in Bend: Cocoa callbacks fired
# inside Window.frame call a capture-less Bend step function, and the C
# side threads the editor state (a String) from call to call, handing it
# back to Bend after the frame. Runtime internals: no ABI promise.
import Base

def Syn.arm(w: Window, st: String, step: String & U32 & String -> String & U32) ->
  IO(Window):
  import "./syn.c"
  import "./syn.js"

def Syn.take(w: Window) -> IO(Window & String & String):
  import "./syn.c"
  import "./syn.js"

def pick(ins: Bool, +s: String, t: String) -> String & U32:
  match ins:
    case True{}:
      (String.append(s, t), U32.from_nat(String.length(s)))
    case False{}:
      (s, U32.from_nat(String.length(s)))

# op 1: append text, answer the old length; op 0: answer the length.
def step(p: String & U32 & String) -> String & U32:
  (s, op, t) = p
  pick(U32.is_eq(op, 1), s, t)

def frames(n: Nat, w: Window) -> IO(Window):
  match n:
    case 0n:
      IO.pure(Window, w)
    case 1n+p:
      do IO<Window>:
        q : Window & Image & List<Event> <- Window.frame(w, Pix{4210752})
        frames(p, Pair.fst(Window, Image & List<Event>, q))

def fin(r: Window & String & String) -> IO(Unit):
  (w, st, log) = r
  do IO<Unit>:
    u : Unit <- IO.print(log)
    v : Unit <- IO.print("Bend state after the frame: \"" ++ st ++ "\"")
    Window.close(w)

def main() -> IO(Unit):
  do IO<Unit>:
    w : Window <- IO.try(Window, Window.open("syn", 200, 100))
    w1 : Window <- frames(2n, w)
    w2 : Window <- Syn.arm(w1, "start:", p => step(p))
    w3 : Window <- frames(3n, w2)
    r : Window & String & String <- Syn.take(w3)
    fin(r)
