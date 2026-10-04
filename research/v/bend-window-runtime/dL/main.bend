import Base

def Demo.answer(x: U32) -> IO(U32):
  import "./d.c"
  import "./d.js"

def main() -> IO(Unit):
  do IO<Unit>:
    v : U32 <- Demo.answer(20)
    IO.print("demo " ++ U32.show(v))
