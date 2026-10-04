import Base

law Gpui: Type

def Gpui.open() -> IO(Result<&1, &1, U32 & String, Gpui>):
  import "./gpui.c"
  import "./gpui.js"

def main() -> IO(Unit):
  IO.print("x")
