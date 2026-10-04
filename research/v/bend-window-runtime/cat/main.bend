import Base

def Text.feed(w: Window) -> IO(Window):
  import "./text.c"
  import "./text.js"

def Text.take(w: Window) -> IO(Window & String):
  import "./text.c"
  import "./text.js"

def fin(r: Window & String) -> IO(Unit):
  (w, s) = r
  do IO<Unit>:
    IO.print("typed text: " ++ s)
    Window.close(w)

def shown(q: Window & Image & List<Event>) -> IO(Unit):
  (w, im, evs) = q
  do IO<Unit>:
    r : Window & String <- Text.take(w)
    fin(r)

def main() -> IO(Unit):
  do IO<Unit>:
    w : Window <- IO.try(Window, Window.open("text", 64, 64))
    w2 : Window <- Text.feed(w)
    q : Window & Image & List<Event> <- Window.frame(w2, Pix{65280})
    shown(q)
