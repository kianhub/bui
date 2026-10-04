import Base

# A self-renewing handler with fuel: each call returns the next handler.
type Handler is Type:
  H{run: U32 -> Pair(U32, Handler)}
  Spent{}

def counter(n: Nat, +step: U32) -> Handler:
  match n:
    case 0n:
      Spent{}
    case 1n+p:
      H{x => ((x + step : U32), counter(p, step))}

def fire(n: Nat, r: Pair(U32, Handler)) -> U32:
  match n r:
    case Zero{} Tuple{s, _}:
      s
    case Succ{p} Tuple{s, H{f}}:
      fire(p, f(s))
    case Succ{p} Tuple{s, Spent{}}:
      s

def main() -> U32:
  fire(3n, (0, counter(4294967295n, 5)))
