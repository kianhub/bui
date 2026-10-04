import Base

def Probe.info(w: Window) -> IO(Window & String):
  import "./probe.c"
  import "./probe.js"

def Probe.keys(w: Window) -> IO(Window & String):
  import "./probe.c"
  import "./probe.js"

def bool_show(b: Bool) -> String:
  match b:
    case True{}:
      "down"
    case False{}:
      "up"

def ev_show(ev: Event) -> String:
  match ev:
    case Key{code, down}:
      "Key{" ++ U32.show(code) ++ " " ++ bool_show(down) ++ "}"
    case Mouse{x, y, button, down}:
      "Mouse{" ++ U32.show(x) ++ "," ++ U32.show(y) ++ " b" ++ U32.show(button) ++ " " ++ bool_show(down) ++ "}"
    case Move{x, y}:
      "Move"
    case Look{dx, dy}:
      "Look"
    case Scroll{x, y, dx, dy}:
      "Scroll"
    case Close{}:
      "Close"

def evs_show(xs: List<Event>) -> String:
  match xs:
    case Nil{}:
      ""
    case ev <> rest:
      ev_show(ev) ++ " " ++ evs_show(rest)

def fin(r: Window & String) -> IO(Unit):
  (w, s) = r
  do IO<Unit>:
    IO.print("after resize: " ++ s)
    Window.close(w)

def shown(q: Window & Image & List<Event>) -> IO(Unit):
  (w, im, evs) = q
  do IO<Unit>:
    IO.print("events: " ++ evs_show(evs))
    r : Window & String <- Probe.info(w)
    fin(r)

def keyed(r: Window & String) -> IO(Unit):
  (w, s) = r
  do IO<Unit>:
    IO.print("fed: " ++ s)
    q : Window & Image & List<Event> <- Window.frame(w, Pix{65280})
    shown(q)

def info(r: Window & String) -> IO(Unit):
  (w, s) = r
  do IO<Unit>:
    IO.print("info: " ++ s)
    k : Window & String <- Probe.keys(w)
    keyed(k)

def main() -> IO(Unit):
  do IO<Unit>:
    w : Window <- IO.try(Window, Window.open("keys", 64, 64))
    r : Window & String <- Probe.info(w)
    info(r)
