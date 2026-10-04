import Base

def Sum.go(n: Nat, acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      Sum.go(p, (acc + 1 : U32))

def heavy(x: U32) -> U32:
  Sum.go(1000n, x)

def step(x: U32, k: U32 -> IO(Unit)) -> IO(Unit):
  k(x)
