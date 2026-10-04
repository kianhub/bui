import Base

def done(q: Window & Image & List<Event>) -> IO(Unit):
  (w, im, evs) = q
  Window.close(w)

def main() -> IO(Unit):
  do IO<Unit>:
    w : Window <- IO.try(Window, Window.open("x", 64, 64))
    q : Window & Image & List<Event> <- Window.frame(w, Pix{65280})
    done(q)
