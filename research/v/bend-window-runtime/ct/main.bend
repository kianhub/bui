import Base

def Text.width(text: String, size: U32) -> IO(U32):
  import "./ffi.c"
  import "./ffi.js"

def main() -> IO(Unit):
  do IO<Unit>:
    w : U32 <- Text.width("Hello, GPUI in Bend", 16)
    IO.print("CoreText width x1000: " ++ U32.show(w))
