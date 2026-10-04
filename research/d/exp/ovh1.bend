import Base

def one(+x: U32) -> U32:
  (x * 3 + 1 : U32)

def loop(+n: Nat, +acc: U32) -> IO(U32):
  match n:
    case 0n:
      IO.pure(U32, acc)
    case 1n+p:
      do IO<U32>:
        +s : U32 <- IO.pure(U32, one!(U32.from_nat(p)))
        loop(p, (acc + s : U32))

def main() -> IO(Unit):
  do IO<Unit>:
    a : U32 <- loop(30000n, 0)
    IO.print("done " ++ U32.show(a))
