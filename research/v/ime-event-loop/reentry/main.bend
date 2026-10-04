# Can a Cocoa callback fired while Window.frame pumps events call back into
# Bend synchronously? The effect stores closures; an NSTextInputClient
# overlay applies them from inside AppKit's key dispatch by re-entering
# corpus_eval (runtime internals, no ABI promise).
import Base

def Cbx.arm(
  w: Window, f: U32 -> U32, g: U32 -> U32, b: U32 -> U32, h: U32 -> U32
) -> IO(Window):
  import "./cbx.c"
  import "./cbx.js"

def Cbx.take(w: Window) -> IO(Window & String):
  import "./cbx.c"
  import "./cbx.js"

def pow2(+n: Nat) -> U32:
  match n:
    case 0n:
      1
    case 1n+p:
      a b = pow2(p) pow2(p)
      (a + b : U32)

def sq(+x: U32) -> U32:
  (x * x : U32)

def frames(n: Nat, w: Window) -> IO(Window):
  match n:
    case 0n:
      IO.pure(Window, w)
    case 1n+p:
      do IO<Window>:
        q : Window & Image & List<Event> <- Window.frame(w, Pix{4210752})
        frames(p, Pair.fst(Window, Image & List<Event>, q))

def fin(r: Window & String) -> IO(Unit):
  (w, s) = r
  do IO<Unit>:
    u : Unit <- IO.print(s)
    Window.close(w)

def main() -> IO(Unit):
  do IO<Unit>:
    k : U32 <- IO.pure(U32, 1000)
    w : Window <- IO.try(Window, Window.open("cb", 200, 100))
    w1 : Window <- frames(2n, w)
    w2 : Window <- Cbx.arm(w1, x => (x * 2 + k : U32), x => (x + pow2(16n) : U32),
      x => sq!(x), x => (x + 7 : U32))
    w3 : Window <- frames(4n, w2)
    r : Window & String <- Cbx.take(w3)
    fin(r)
