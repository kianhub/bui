# A ticker forked beside a window: it sleeps 50 ms ten times and prints
# the measured gap each time, while App.run renders 120 frames.
import Base

def ticker(n: Nat, +last: Nat) -> IO(Unit):
  match n:
    case 0n:
      IO.print("ticker done")
    case 1n+k:
      do IO<Unit>:
        IO.sleep(50)
        +now : Nat <- IO.now()
        IO.print("tick gap ms " ++ Nat.show(Nat.sub(now, last)))
        ticker(k, now)

def grad(+d: Nat, +x: U32, +y: U32, +n: U32) -> Image:
  match d:
    case 0n:
      Pix{(((x .&. 255) << 16n) .|. ((y .&. 255) << 8n) .|. (n .&. 255) : U32)}
    case 1n+e:
      +h = U32.shln(1, e)
      +x1 = (x + h : U32)
      +y1 = (y + h : U32)
      tl tr bl br = grad(e, x, y, n) grad(e, x1, y, n) grad(e, x, y1, n) grad(e, x1, y1, n)
      Qua{tl, tr, bl, br}

def view(n: U32) -> U32 & Image:
  +m = n
  (m, grad(9n, 0, 0, m))

def stop(done: Bool, +n: U32) -> IO(Maybe<U32>):
  match done:
    case True{}:
      do IO<Maybe<U32>>:
        IO.print("frames done")
        IO.pure(Maybe<U32>, None{})
    case False{}:
      IO.pure(Maybe<U32>, Some{U32.inc(n)})

def tick(events: List<Event>, n: U32) -> IO(Maybe<U32>):
  +m = n
  do IO<Maybe<U32>>:
    IO.sleep(0)
    stop((m >= 119 : U32), m)

def main() -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    IO.spawn(Unit, ticker(10n, t0))
    App.run(~U32, ~App{view, tick}, "conc", 512, 512, 0)
