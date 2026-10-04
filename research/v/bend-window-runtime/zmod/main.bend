import Base

def Z.version() -> IO(String):
  import "./z.c"
  import "./z.js"

def main() -> IO(Unit):
  do IO<Unit>:
    v : String <- Z.version()
    IO.print("zlib " ++ v)
