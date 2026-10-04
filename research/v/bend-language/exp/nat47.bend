import Base

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print(Nat.show(Nat.add(Nat.mul(Nat.mul(65536n, 65536n), 32768n), Nat.sub(Nat.mul(Nat.mul(65536n, 65536n), 32768n), 1n))))
