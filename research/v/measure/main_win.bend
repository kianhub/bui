
# Window main: a real Base window, Window.frame as the present.
def wsplit(shown: Window & Image & List<Event>, a: Array<Glyph>, +t1: U32) -> Array<Glyph> & Image & U32 & Window:
  (win, img, events) = shown
  (a, img, t1, win)

def wpresent(s: Array<Glyph> & Image & U32, win: Window) -> IO(Array<Glyph> & Image & U32 & Window):
  (a, img, t1) = s
  do IO<Array<Glyph> & Image & U32 & Window>:
    shown : Window & Image & List<Event> <- Window.frame(win, img)
    IO.pure(Array<Glyph> & Image & U32 & Window, wsplit(shown, a, t1))

def wdrop.fin(u: Unit, a: Array<Glyph>, +t1: U32, win: Window) -> Array<Glyph> & U32 & Window:
  match u:
    case Unit{}:
      (a, t1, win)

def wdrop(s: Array<Glyph> & Image & U32 & Window) -> Array<Glyph> & U32 & Window:
  (a, img, t1, win) = s
  wdrop.fin(Image.drop!(img), a, t1, win)

def wsay2(a: Array<Glyph>, win: Window, +t1: U32, +hd: String, +t0: U32, +t2: U32, +t3: U32, +t4: U32, +pace: U32, k: (Array<Glyph> & Window) -> IO(Unit)) -> IO(Unit):
  do IO<Unit>:
    +rss : U32 <- Rss.kb()
    IO.print(hd ++ " build_us " ++ U32.show((t1 - t0 : U32)) ++ " render_us " ++ U32.show((t2 - t1 : U32))
      ++ " present_us " ++ U32.show((t3 - t2 : U32)) ++ " drop_us " ++ U32.show((t4 - t3 : U32))
      ++ " frame_us " ++ U32.show((t4 - t0 : U32)) ++ " rss_kb " ++ U32.show(rss))
    Unit <- pace.go(U32.is_ne(pace, 0), pace)
    k((a, win))

def wsay(r: Array<Glyph> & U32 & Window, +hd: String, +t0: U32, +t2: U32, +t3: U32, +t4: U32, +pace: U32, k: (Array<Glyph> & Window) -> IO(Unit)) -> IO(Unit):
  (a, t1, win) = r
  wsay2(a, win, t1, hd, t0, t2, t3, t4, pace, k)

def wend(aw: Array<Glyph> & Window) -> IO(Unit):
  (a, win) = aw
  do IO<Unit>:
    Unit <- Window.close(win)
    finish(a)

def wloop(+n: Nat, +cfg: Cfg, aw: Array<Glyph> & Window) -> IO(Unit):
  match n:
    case 0n:
      wend(aw)
    case 1n+p:
      Cfg{+cols, +rows, +w, +h, +frames, +pace, +mode, blit, +g, check} = cfg
      (a, win) = aw
      +i = (frames - U32.from_nat(p) - 1 : U32)
      +big = isbig(w, h)
      do IO<Unit>:
        +t0 : U32 <- Clock.us()
        d : Array<Glyph> & Image & U32 <- draw(U32.is_eq(mode, 1), cols, rows, w, h, g, frame.ft(i), a, big)
        +t2 : U32 <- Clock.us()
        s : Array<Glyph> & Image & U32 & Window <- wpresent(d, win)
        +t3 : U32 <- Clock.us()
        r : Array<Glyph> & U32 & Window <- IO.pure(Array<Glyph> & U32 & Window, wdrop(s))
        +t4 : U32 <- Clock.us()
        wsay(r, line.head(mode, cols, rows, w, h, i), t0, t2, t3, t4, pace, aw2 => wloop(p, cfg, aw2))

def wrun(+cfg: Cfg, a: Array<Glyph>) -> IO(Unit):
  Cfg{cols, rows, +w, +h, +frames, pace, mode, blit, g, check} = cfg
  do IO<Unit>:
    win : Window <- IO.try(Window, Window.open("ui", w, h))
    wloop(U32.to_nat(frames), cfg, (a, win))

def main() -> IO(Unit):
  do IO<Unit>:
    +cfg : Cfg <- config()
    wrun(cfg, atlas())
