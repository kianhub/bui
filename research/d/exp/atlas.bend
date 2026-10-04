import Base

# Can every lane read one shared texture? A 256x256 "atlas" as one
# Array<U32>, handed down a 2^14-leaf fork tree with the @unsafe
# Array.fork (O(1) aliasing handles); each leaf samples it 127 times.

def Clock.us() -> IO(U32):
  import "./clock.c"
  import "./clock.js"

def fill(n: Nat, a: Array<U32>, +i: U32) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+p:
      fill(p, Array.set(U32, a, i, U32.and((i * 2654435761 : U32), 255)), (i + 1 : U32))

def sample.add(r: Array<U32> & U32, +acc: U32) -> Array<U32> & U32:
  (a, +v) = r
  (a, (acc * 31 + v : U32))

def sample.go(n: Nat, r: Array<U32> & U32, +i: U32) -> Array<U32> & U32:
  match n:
    case 0n:
      r
    case 1n+p:
      (a, +acc) = r
      +idx = U32.and(U32.shrn((i * 2654435761 : U32), 16n), 65535)
      sample.go(p, sample.add(Array.get(U32, a, idx), acc), (i + 1 : U32))

def walk.join(ra: Array<U32> & U32, rb: Array<U32> & U32) -> Array<U32> & U32:
  (x1, +s1) = ra
  (x2, +s2) = rb
  (Array.join(U32, x1, x2), (s1 + s2 : U32))

def walk.split(+d: Nat, +i: U32, hs: Array<U32> & Array<U32>) -> Array<U32> & U32:
  match d:
    case 0n:
      (a1, a2) = hs
      walk.join(sample.go(127n, (a1, 0), (i * 127 : U32)), (a2, 0))
    case 1n+p:
      (a1, a2) = hs
      ra rb = walk.split(p, (i * 2 : U32), Array.fork(U32, a1)) walk.split(p, (i * 2 + 1 : U32), Array.fork(U32, a2))
      walk.join(ra, rb)

def walk(+d: Nat, a: Array<U32>) -> Array<U32> & U32:
  walk.split(d, 0, Array.fork(U32, a))

def loop.say(r: Array<U32> & U32, +us: U32, k: Array<U32> -> IO(Unit)) -> IO(Unit):
  (a, +s) = r
  do IO<Unit>:
    IO.print("atlas_us " ++ U32.show(us) ++ " sum " ++ U32.show(s))
    k(a)

def loop(+n: Nat, a: Array<U32>) -> IO(Unit):
  match n:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      do IO<Unit>:
        +t0 : U32 <- Clock.us()
        r : Array<U32> & U32 <- IO.pure(Array<U32> & U32, walk!(14n, a))
        +t1 : U32 <- Clock.us()
        loop.say(r, (t1 - t0 : U32), a2 => loop(p, a2))

def main() -> IO(Unit):
  do IO<Unit>:
    loop(30n, fill(65536n, [0 : U32^16n], 0))
