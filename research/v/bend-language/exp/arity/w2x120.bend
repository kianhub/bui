import Base

type R is Data:
  R{f0: F32, f1: F32, f2: F32, f3: F32, f4: F32, f5: F32, f6: F32, f7: F32, f8: F32, f9: F32, f10: F32, f11: F32, f12: F32, f13: F32, f14: F32, f15: F32, f16: F32, f17: F32, f18: F32, f19: F32, f20: F32, f21: F32, f22: F32, f23: F32, f24: F32, f25: F32, f26: F32, f27: F32, f28: F32, f29: F32, f30: F32, f31: F32, f32: F32, f33: F32, f34: F32, f35: F32, f36: F32, f37: F32, f38: F32, f39: F32, f40: F32, f41: F32, f42: F32, f43: F32, f44: F32, f45: F32, f46: F32, f47: F32, f48: F32, f49: F32, f50: F32, f51: F32, f52: F32, f53: F32, f54: F32, f55: F32, f56: F32, f57: F32, f58: F32, f59: F32, f60: F32, f61: F32, f62: F32, f63: F32, f64: F32, f65: F32, f66: F32, f67: F32, f68: F32, f69: F32, f70: F32, f71: F32, f72: F32, f73: F32, f74: F32, f75: F32, f76: F32, f77: F32, f78: F32, f79: F32, f80: F32, f81: F32, f82: F32, f83: F32, f84: F32, f85: F32, f86: F32, f87: F32, f88: F32, f89: F32, f90: F32, f91: F32, f92: F32, f93: F32, f94: F32, f95: F32, f96: F32, f97: F32, f98: F32, f99: F32, f100: F32, f101: F32, f102: F32, f103: F32, f104: F32, f105: F32, f106: F32, f107: F32, f108: F32, f109: F32, f110: F32, f111: F32, f112: F32, f113: F32, f114: F32, f115: F32, f116: F32, f117: F32, f118: F32, f119: F32}

def sumr(n: Nat, a: R, b: R) -> F32:
  match n:
    case 0n:
      R{a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25, a26, a27, a28, a29, a30, a31, a32, a33, a34, a35, a36, a37, a38, a39, a40, a41, a42, a43, a44, a45, a46, a47, a48, a49, a50, a51, a52, a53, a54, a55, a56, a57, a58, a59, a60, a61, a62, a63, a64, a65, a66, a67, a68, a69, a70, a71, a72, a73, a74, a75, a76, a77, a78, a79, a80, a81, a82, a83, a84, a85, a86, a87, a88, a89, a90, a91, a92, a93, a94, a95, a96, a97, a98, a99, a100, a101, a102, a103, a104, a105, a106, a107, a108, a109, a110, a111, a112, a113, a114, a115, a116, a117, a118, a119} = a
      R{b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31, b32, b33, b34, b35, b36, b37, b38, b39, b40, b41, b42, b43, b44, b45, b46, b47, b48, b49, b50, b51, b52, b53, b54, b55, b56, b57, b58, b59, b60, b61, b62, b63, b64, b65, b66, b67, b68, b69, b70, b71, b72, b73, b74, b75, b76, b77, b78, b79, b80, b81, b82, b83, b84, b85, b86, b87, b88, b89, b90, b91, b92, b93, b94, b95, b96, b97, b98, b99, b100, b101, b102, b103, b104, b105, b106, b107, b108, b109, b110, b111, b112, b113, b114, b115, b116, b117, b118, b119} = b
      (a0 + b1 : F32)
    case 1n+p:
      sumr(p, a, b)

def go(n: Nat, +x: F32) -> F32:
  sumr(n, R{x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x}, R{x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x, x})

def main() -> IO(Unit):
  do IO<Unit>:
    +t : Nat <- IO.now()
    IO.print(F32.show(go(U32.to_nat(U32.and(U32.from_nat(t), 3)), U32.to_f32(U32.and(U32.from_nat(t), 1)))))
