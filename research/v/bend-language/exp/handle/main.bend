import Base

law Gpui: Type

def Gpui():
  Window

def Gpui.open() -> IO(Result<&1, &1, U32 & String, Gpui>):
  import "./gpui.c"
  import "./gpui.js"

def Gpui.close(g: Gpui) -> IO(U32):
  import "./gpui.c"
  import "./gpui.js"

def main() -> IO(Unit):
  do IO<Unit>:
    g : Gpui <- IO.try(Gpui, Gpui.open())
    v : U32 <- Gpui.close(g)
    IO.print("handle word seen by close: " ++ U32.show(v))
