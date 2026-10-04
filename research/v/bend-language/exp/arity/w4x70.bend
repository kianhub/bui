import Base

type R is Data:
  R{f0: F32, f1: F32, f2: F32, f3: F32, f4: F32, f5: F32, f6: F32, f7: F32, f8: F32, f9: F32, f10: F32, f11: F32, f12: F32, f13: F32, f14: F32, f15: F32, f16: F32, f17: F32, f18: F32, f19: F32, f20: F32, f21: F32, f22: F32, f23: F32, f24: F32, f25: F32, f26: F32, f27: F32, f28: F32, f29: F32, f30: F32, f31: F32, f32: F32, f33: F32, f34: F32, f35: F32, f36: F32, f37: F32, f38: F32, f39: F32, f40: F32, f41: F32, f42: F32, f43: F32, f44: F32, f45: F32, f46: F32, f47: F32, f48: F32, f49: F32, f50: F32, f51: F32, f52: F32, f53: F32, f54: F32, f55: F32, f56: F32, f57: F32, f58: F32, f59: F32, f60: F32, f61: F32, f62: F32, f63: F32, f64: F32, f65: F32, f66: F32, f67: F32, f68: F32, f69: F32}

def sumr(n: Nat, a: R, b: R, c: R, d: R) -> F32:
  match n:
    case 0n:
      R{a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25, a26, a27, a28, a29, a30, a31, a32, a33, a34, a35, a36, a37, a38, a39, a40, a41, a42, a43, a44, a45, a46, a47, a48, a49, a50, a51, a52, a53, a54, a55, a56, a57, a58, a59, a60, a61, a62, a63, a64, a65, a66, a67, a68, a69} = a
      R{b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31, b32, b33, b34, b35, b36, b37, b38, b39, b40, b41, b42, b43, b44, b45, b46, b47, b48, b49, b50, b51, b52, b53, b54, b55, b56, b57, b58, b59, b60, b61, b62, b63, b64, b65, b66, b67, b68, b69} = b
      R{c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12, c13, c14, c15, c16, c17, c18, c19, c20, c21, c22, c23, c24, c25, c26, c27, c28, c29, c30, c31, c32, c33, c34, c35, c36, c37, c38, c39, c40, c41, c42, c43, c44, c45, c46, c47, c48, c49, c50, c51, c52, c53, c54, c55, c56, c57, c58, c59, c60, c61, c62, c63, c64, c65, c66, c67, c68, c69} = c
      R{d0, d1, d2, d3, d4, d5, d6, d7, d8, d9, d10, d11, d12, d13, d14, d15, d16, d17, d18, d19, d20, d21, d22, d23, d24, d25, d26, d27, d28, d29, d30, d31, d32, d33, d34, d35, d36, d37, d38, d39, d40, d41, d42, d43, d44, d45, d46, d47, d48, d49, d50, d51, d52, d53, d54, d55, d56, d57, d58, d59, d60, d61, d62, d63, d64, d65, d66, d67, d68, d69} = d
      (a0 + b1 + c2 + d3 : F32)
    case 1n+p:
      sumr(p, a, b, c, d)

def go(n: Nat, +x: F32) -> F32:
  sumr(n, R{x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x}, R{x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x}, R{x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x}, R{x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x})

def main() -> IO(Unit):
  do IO<Unit>:
    +t : Nat <- IO.now()
    IO.print(F32.show(go(U32.to_nat(U32.and(U32.from_nat(t), 3)), U32.to_f32(U32.and(U32.from_nat(t), 1)))))
