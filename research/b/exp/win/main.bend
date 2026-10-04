# A user effect on Base's Window handle: reads the NSWindow's backing
# scale and its CAMetalLayer's contentsScale and drawableSize.
import Base

def Win.info(w: Window) -> IO(Window & String):
  import "./win.c"
  import "./win.js"

def done(q: Window & Image & List<Event>) -> IO(Unit):
  (w, im, evs) = q
  Window.close(w)

def show(r: Window & String) -> IO(Unit):
  (w, s) = r
  do IO<Unit>:
    IO.print(s)
    q : Window & Image & List<Event> <- Window.frame(w, Pix{65280})
    done(q)

def main() -> IO(Unit):
  do IO<Unit>:
    w : Window <- IO.try(Window, Window.open("info", 512, 512))
    r : Window & String <- Win.info(w)
    show(r)
