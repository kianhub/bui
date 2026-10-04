import Base

def Text.width(s: String, px: U32) -> IO(U32):
  import "./ct.c"
  import "./ct.js"

def main() -> IO(Unit):
  do IO<Unit>:
    w : U32 <- Text.width("Hello, GPUI in Bend", 14)
    IO.print("CoreText width x100: " ++ U32.show(w))
