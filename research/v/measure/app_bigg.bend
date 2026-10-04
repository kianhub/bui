# A frame counter: a full-detail 512 x 512 gradient each frame (262144
# Pix leaves, built with parallel lets), 180 frames, then it prints the
# elapsed ms and the events seen, and quits.
import Base

type S is Data:
  S{n: U32, t0: Nat, evs: U32}

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

def view(s: S) -> S & Image:
  S{+n, t0, evs} = s
  (S{n, t0, evs}, grad!(11n, 0, 0, n))

def count(xs: List<Event>) -> U32:
  match xs:
    case Nil{}:
      0
    case e <> rest:
      U32.inc(count(rest))

def fin(done: Bool, +n: U32, t0: Nat, now: Nat, +evs: U32) -> IO(Maybe<S>):
  match done:
    case True{}:
      do IO<Maybe<S>>:
        IO.print("frames " ++ U32.show(U32.inc(n)) ++ " ms " ++ Nat.show(Nat.sub(now, t0)) ++ " events " ++ U32.show(evs))
        IO.pure(Maybe<S>, None{})
    case False{}:
      IO.pure(Maybe<S>, Some{S{U32.inc(n), t0, evs}})

def tick(events: List<Event>, s: S) -> IO(Maybe<S>):
  S{+n, +t0, evs} = s
  do IO<Maybe<S>>:
    now : Nat <- IO.now()
    fin((n >= 119 : U32), n, t0, now, (evs + count(events) : U32))

def main() -> IO(Unit):
  do IO<Unit>:
    t0 : Nat <- IO.now()
    App.run(~S, ~App{view, tick}, "bigg", 1920, 1200, S{0, t0, 0})
