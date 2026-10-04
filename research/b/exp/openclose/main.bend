import Base

def main() -> IO(Unit):
  do IO<Unit>:
    w : Window <- IO.try(Window, Window.open("x", 64, 64))
    Window.close(w)
