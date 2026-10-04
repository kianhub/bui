import Base

type Refine is Data:
  Refine{f0: Maybe<&2, F32>, f1: Maybe<&2, F32>, f2: Maybe<&2, F32>, f3: Maybe<&2, F32>, f4: Maybe<&2, F32>, f5: Maybe<&2, F32>, f6: Maybe<&2, F32>, f7: Maybe<&2, F32>, f8: Maybe<&2, F32>, f9: Maybe<&2, F32>, f10: Maybe<&2, F32>, f11: Maybe<&2, F32>, f12: Maybe<&2, F32>, f13: Maybe<&2, F32>, f14: Maybe<&2, F32>, f15: Maybe<&2, F32>, f16: Maybe<&2, F32>, f17: Maybe<&2, F32>, f18: Maybe<&2, F32>, f19: Maybe<&2, F32>, f20: Maybe<&2, F32>, f21: Maybe<&2, F32>, f22: Maybe<&2, F32>, f23: Maybe<&2, F32>, f24: Maybe<&2, F32>, f25: Maybe<&2, F32>, f26: Maybe<&2, F32>, f27: Maybe<&2, F32>, f28: Maybe<&2, F32>, f29: Maybe<&2, F32>, f30: Maybe<&2, F32>, f31: Maybe<&2, F32>, f32: Maybe<&2, F32>, f33: Maybe<&2, F32>, f34: Maybe<&2, F32>, f35: Maybe<&2, F32>, f36: Maybe<&2, F32>, f37: Maybe<&2, F32>, f38: Maybe<&2, F32>, f39: Maybe<&2, F32>, f40: Maybe<&2, F32>, f41: Maybe<&2, F32>, f42: Maybe<&2, F32>, f43: Maybe<&2, F32>, f44: Maybe<&2, F32>, f45: Maybe<&2, F32>, f46: Maybe<&2, F32>, f47: Maybe<&2, F32>, f48: Maybe<&2, F32>, f49: Maybe<&2, F32>, f50: Maybe<&2, F32>, f51: Maybe<&2, F32>, f52: Maybe<&2, F32>, f53: Maybe<&2, F32>, f54: Maybe<&2, F32>, f55: Maybe<&2, F32>, f56: Maybe<&2, F32>, f57: Maybe<&2, F32>, f58: Maybe<&2, F32>, f59: Maybe<&2, F32>, f60: Maybe<&2, F32>, f61: Maybe<&2, F32>, f62: Maybe<&2, F32>, f63: Maybe<&2, F32>, f64: Maybe<&2, F32>, f65: Maybe<&2, F32>, f66: Maybe<&2, F32>, f67: Maybe<&2, F32>, f68: Maybe<&2, F32>, f69: Maybe<&2, F32>}

def pk0(a: Maybe<&2, F32>, b: Maybe<&2, F32>) -> Maybe<&2, F32>:
  match b:
    case None{}:
      a
    case Some{v}:
      Some{v}

def refine(a: Refine, b: Refine) -> Refine:
  Refine{a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25, a26, a27, a28, a29, a30, a31, a32, a33, a34, a35, a36, a37, a38, a39, a40, a41, a42, a43, a44, a45, a46, a47, a48, a49, a50, a51, a52, a53, a54, a55, a56, a57, a58, a59, a60, a61, a62, a63, a64, a65, a66, a67, a68, a69} = a
  Refine{b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10, b11, b12, b13, b14, b15, b16, b17, b18, b19, b20, b21, b22, b23, b24, b25, b26, b27, b28, b29, b30, b31, b32, b33, b34, b35, b36, b37, b38, b39, b40, b41, b42, b43, b44, b45, b46, b47, b48, b49, b50, b51, b52, b53, b54, b55, b56, b57, b58, b59, b60, b61, b62, b63, b64, b65, b66, b67, b68, b69} = b
  Refine{pk0(a0, b0), pk0(a1, b1), pk0(a2, b2), pk0(a3, b3), pk0(a4, b4), pk0(a5, b5), pk0(a6, b6), pk0(a7, b7), pk0(a8, b8), pk0(a9, b9), pk0(a10, b10), pk0(a11, b11), pk0(a12, b12), pk0(a13, b13), pk0(a14, b14), pk0(a15, b15), pk0(a16, b16), pk0(a17, b17), pk0(a18, b18), pk0(a19, b19), pk0(a20, b20), pk0(a21, b21), pk0(a22, b22), pk0(a23, b23), pk0(a24, b24), pk0(a25, b25), pk0(a26, b26), pk0(a27, b27), pk0(a28, b28), pk0(a29, b29), pk0(a30, b30), pk0(a31, b31), pk0(a32, b32), pk0(a33, b33), pk0(a34, b34), pk0(a35, b35), pk0(a36, b36), pk0(a37, b37), pk0(a38, b38), pk0(a39, b39), pk0(a40, b40), pk0(a41, b41), pk0(a42, b42), pk0(a43, b43), pk0(a44, b44), pk0(a45, b45), pk0(a46, b46), pk0(a47, b47), pk0(a48, b48), pk0(a49, b49), pk0(a50, b50), pk0(a51, b51), pk0(a52, b52), pk0(a53, b53), pk0(a54, b54), pk0(a55, b55), pk0(a56, b56), pk0(a57, b57), pk0(a58, b58), pk0(a59, b59), pk0(a60, b60), pk0(a61, b61), pk0(a62, b62), pk0(a63, b63), pk0(a64, b64), pk0(a65, b65), pk0(a66, b66), pk0(a67, b67), pk0(a68, b68), pk0(a69, b69)}

def get3(r: Refine) -> F32:
  Refine{a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20, a21, a22, a23, a24, a25, a26, a27, a28, a29, a30, a31, a32, a33, a34, a35, a36, a37, a38, a39, a40, a41, a42, a43, a44, a45, a46, a47, a48, a49, a50, a51, a52, a53, a54, a55, a56, a57, a58, a59, a60, a61, a62, a63, a64, a65, a66, a67, a68, a69} = r
  match a3:
    case None{}:
      0.0
    case Some{v}:
      v

def main() -> IO(Unit):
  IO.print(F32.show(get3(refine(Refine{None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}, None{}}, Refine{Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}, None{}, None{}, Some{1.5}}))))
