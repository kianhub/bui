# Two windows framed alternately, 240 rounds; prints the elapsed ms and
# the events each saw.
import Base

def count(xs: List<Event>) -> U32:
  match xs:
    case Nil{}:
      0
    case e <> rest:
      U32.inc(count(rest))

def merge(ra: Window & Image & List<Event>, rb: Window & Image & List<Event>, ea: U32, eb: U32) -> Window & Window & U32 & U32:
  (a, ia, xa) = ra
  (b, ib, xb) = rb
  (a, b, (ea + count(xa) : U32), (eb + count(xb) : U32))

def rounds(n: Nat, st: Window & Window & U32 & U32) -> IO(Window & Window & U32 & U32):
  match n:
    case 0n:
      IO.pure(Window & Window & U32 & U32, st)
    case 1n+k:
      (a, b, ea, eb) = st
      do IO<Window & Window & U32 & U32>:
        ra : Window & Image & List<Event> <- Window.frame(a, Pix{16711680})
        rb : Window & Image & List<Event> <- Window.frame(b, Pix{255})
        rounds(k, merge(ra, rb, ea, eb))

def fin(t0: Nat, r: Window & Window & U32 & U32) -> IO(Unit):
  (a, b, ea, eb) = r
  do IO<Unit>:
    t1 : Nat <- IO.now()
    IO.print("240 rounds ms " ++ Nat.show(Nat.sub(t1, t0)) ++ " events " ++ U32.show(ea) ++ " " ++ U32.show(eb))
    Window.close(a)
    Window.close(b)

def main() -> IO(Unit):
  do IO<Unit>:
    a : Window <- IO.try(Window, Window.open("A", 256, 256))
    b : Window <- IO.try(Window, Window.open("B", 256, 256))
    t0 : Nat <- IO.now()
    r : Window & Window & U32 & U32 <- rounds(240n, (a, b, 0, 0))
    fin(t0, r)
