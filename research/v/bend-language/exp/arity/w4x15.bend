import Base

type R is Data:
  R{f0: F32, f1: F32, f2: F32, f3: F32, f4: F32, f5: F32, f6: F32, f7: F32, f8: F32, f9: F32, f10: F32, f11: F32, f12: F32, f13: F32, f14: F32}

def sumr(n: Nat, a: R, b: R, c: R, d: R) -> F32:
  match n:
    case 0n:
      R{a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14} = a
      R{b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14} = b
      R{c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14} = c
      R{d0, d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11, d12, d13, d14} = d
      (a0 + b1 + c2 + d3 : F32)
    case 1n+p:
      sumr(p, a, b, c, d)

def go(n: Nat, +x: F32) -> F32:
  sumr(n, R{x, x, x, x, x, x, x, x, x, x, x, x, x, x, x}, R{x, x, x, x, x, x, x, x, x, x, x, x, x, x, x}, R{x, x, x, x, x, x, x, x, x, x, x, x, x, x, x}, R{x, x, x, x, x, x, x, x, x, x, x, x, x, x, x})

def main() -> IO(Unit):
  do IO<Unit>:
    +t : Nat <- IO.now()
    IO.print(F32.show(go(U32.to_nat(U32.and(U32.from_nat(t), 3)), U32.to_f32(U32.and(U32.from_nat(t), 1)))))
