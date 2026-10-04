import Base

# 2^48 - 1 = 65536 * 65536 * 65536 - 1
def main() -> Nat:
  Nat.sub(Nat.mul(Nat.mul(65536n, 65536n), 65536n), 1n)
