import Base

def run_all(fs: List<&1, U32 -> U32>, s: U32) -> U32:
  match fs:
    case Nil{}:
      s
    case Con{f, rest}:
      run_all(rest, f(s))

def main() -> U32:
  a : U32 = 1
  b : U32 = 10
  run_all([x => (x + a : U32), x => (x * b : U32)], 4)
