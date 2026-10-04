import Base

def inc(x: U32) -> U32:
  (x + 1 : U32)

def twice(f: U32 -> U32, x: U32) -> U32:
  f(f(x))

def main() -> U32:
  twice(inc, 40)
