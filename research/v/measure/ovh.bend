import Base

# Bang overhead: a single-task bang, and trivial-leaf fork trees of
# depth 10, 14 and 16 (1024, 16384, 65536 leaves).

def Clock.us() -> IO(U32):
  import "./clock.c"
  import "./clock.js"

def one(+x: U32) -> U32:
  (x * 3 + 1 : U32)

def tree(+d: Nat, +i: U32) -> U32:
  match d:
    case 0n:
      i
    case 1n+p:
      a b = tree(p, (i * 2 : U32)) tree(p, (i * 2 + 1 : U32))
      (a + b : U32)

def run(k: Nat, +x: U32) -> U32:
  match k:
    case 0n:
      one!(x)
    case 1n:
      tree!(10n, x)
    case 2n:
      tree!(14n, x)
    case 3n:
      tree!(16n, x)
    case _:
      one(x)

def loop(+k: Nat, +n: Nat, +acc: U32) -> IO(U32):
  match n:
    case 0n:
      IO.pure(U32, acc)
    case 1n+p:
      do IO<U32>:
        +t0 : U32 <- Clock.us()
        +s : U32 <- IO.pure(U32, run(k, U32.from_nat(p)))
        +t1 : U32 <- Clock.us()
        IO.print("k " ++ Nat.show(k) ++ " us " ++ U32.show((t1 - t0 : U32)) ++ " sum " ++ U32.show(s))
        loop(k, p, (acc + s : U32))

def main() -> IO(Unit):
  do IO<Unit>:
    a : U32 <- loop(0n, 40n, 0)
    b : U32 <- loop(1n, 40n, 0)
    c : U32 <- loop(2n, 40n, 0)
    d : U32 <- loop(3n, 40n, 0)
    e : U32 <- loop(4n, 40n, 0)
    IO.print("done " ++ U32.show((a + b + c + d + e : U32)))
