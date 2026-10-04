import Base

type R is Data:
  R{f0: F32, f1: F32, f2: F32, f3: F32, f4: F32, f5: F32, f6: F32, f7: F32, f8: F32, f9: F32, f10: F32, f11: F32, f12: F32, f13: F32, f14: F32}

def bump(r: R) -> R:
  R{v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11, v12, v13, v14} = r
  R{(v0 + 0.0 : F32), (v1 + 1.0 : F32), (v2 + 2.0 : F32), (v3 + 3.0 : F32), (v4 + 4.0 : F32), (v5 + 5.0 : F32), (v6 + 6.0 : F32), (v7 + 7.0 : F32), (v8 + 8.0 : F32), (v9 + 9.0 : F32), (v10 + 10.0 : F32), (v11 + 11.0 : F32), (v12 + 12.0 : F32), (v13 + 13.0 : F32), (v14 + 14.0 : F32)}

def sumr(n: Nat, r0: R, r1: R, r2: R, r3: R) -> F32:
  match n:
    case 0n:
      R{r0_0, r0_1, r0_2, r0_3, r0_4, r0_5, r0_6, r0_7, r0_8, r0_9, r0_10, r0_11, r0_12, r0_13, r0_14} = r0
      R{r1_0, r1_1, r1_2, r1_3, r1_4, r1_5, r1_6, r1_7, r1_8, r1_9, r1_10, r1_11, r1_12, r1_13, r1_14} = r1
      R{r2_0, r2_1, r2_2, r2_3, r2_4, r2_5, r2_6, r2_7, r2_8, r2_9, r2_10, r2_11, r2_12, r2_13, r2_14} = r2
      R{r3_0, r3_1, r3_2, r3_3, r3_4, r3_5, r3_6, r3_7, r3_8, r3_9, r3_10, r3_11, r3_12, r3_13, r3_14} = r3
      (r0_0 + r0_1 + r0_2 + r0_3 + r0_4 + r0_5 + r0_6 + r0_7 + r0_8 + r0_9 + r0_10 + r0_11 + r0_12 + r0_13 + r0_14 + r1_0 + r1_1 + r1_2 + r1_3 + r1_4 + r1_5 + r1_6 + r1_7 + r1_8 + r1_9 + r1_10 + r1_11 + r1_12 + r1_13 + r1_14 + r2_0 + r2_1 + r2_2 + r2_3 + r2_4 + r2_5 + r2_6 + r2_7 + r2_8 + r2_9 + r2_10 + r2_11 + r2_12 + r2_13 + r2_14 + r3_0 + r3_1 + r3_2 + r3_3 + r3_4 + r3_5 + r3_6 + r3_7 + r3_8 + r3_9 + r3_10 + r3_11 + r3_12 + r3_13 + r3_14 : F32)
    case 1n+p:
      sumr(p, bump(r0), bump(r1), bump(r2), bump(r3))

def go(n: Nat, +x: F32) -> F32:
  sumr(n, R{x, x, x, x, x, x, x, x, x, x, x, x, x, x, x}, R{x, x, x, x, x, x, x, x, x, x, x, x, x, x, x}, R{x, x, x, x, x, x, x, x, x, x, x, x, x, x, x}, R{x, x, x, x, x, x, x, x, x, x, x, x, x, x, x})

def main() -> IO(Unit):
  do IO<Unit>:
    +t : Nat <- IO.now()
    IO.print(F32.show(go(U32.to_nat(U32.and(U32.from_nat(t), 3)), U32.to_f32(U32.and(U32.from_nat(t), 1)))))
