import Base

### one "frame": 2^9 rows x 768 cells of number text, rows built in parallel
def cell(+x: U32, +y: U32) -> String:
  U32.show(x) ++ " " ++ U32.show(y) ++ "\n"

def row(n: Nat, +x: U32, +y: U32) -> String:
  match n:
    case 0n:
      ""
    case 1n+p:
      cell(x, y) ++ row(p, (x + 1 : U32), y)

def rows(+d: Nat, +y0: U32) -> String:
  match d:
    case 0n:
      row(768n, 0, y0)
    case 1n+p:
      +half = (1 << p : U32)
      a b = rows(p, y0) rows(p, (y0 + half : U32))
      a ++ b

### the same pure work 24 times; prints ms per round
def loop(n: Nat) -> IO(Unit):
  match n:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      do IO<Unit>:
        t0 : Nat <- IO.now()
        IO.write(Nat.show(String.length(rows(3n, 0))) ++ ":")
        t1 : Nat <- IO.now()
        IO.print(Nat.show(Nat.sub(t1, t0)))
        loop(p)

def main() -> IO(Unit):
  loop(3000n)
