# Gap 3, real window at 2x (PR #1108 window.c gives a backing-scale drawable):
# Bend builds ui_common's Scene, P3.present renders it straight into the
# Window handle's CAMetalLayer drawable (vsync-paced present), lists handed back.
def P3.draw(qs: Qs, gs: Gs, w: U32, h: U32, mode: U32) -> IO(Qs & Gs):
  import "./p3fx.c"
  import "./p3fx.js"

def P3.present(win: Window, qs: Qs, gs: Gs, mode: U32) -> IO(Window & Qs & Gs):
  import "./p3fx.c"
  import "./p3fx.js"

def P3.dump(k: U32) -> IO(U32):
  import "./p3fx.c"
  import "./p3fx.js"

def Blit.dump(k: U32) -> IO(U32):
  import "./blit.c"
  import "./blit.js"

def p3w.drop(r: Window & Qs & Gs) -> Window & Unit:
  (win, qs, gs) = r
  (win, tile.unit(Qs.sink(qs), Gs.sink(gs)))

def p3w.say(r: Window & Unit, +hd: String, +t0: U32, +t1: U32, +t2: U32, k: Window -> IO(Unit)) -> IO(Unit):
  (win, u) = r
  do IO<Unit>:
    IO.print(hd ++ " build_us " ++ U32.show((t1 - t0 : U32)) ++ " present_us " ++ U32.show((t2 - t1 : U32)) ++ " frame_us " ++ U32.show((t2 - t0 : U32)))
    k(win)

def p3w.step(r: Array<Glyph> & Gs, qs: Qs, win: Window, +mode: U32, +hd: String, +t0: U32, +t1: U32, k: Array<Glyph> -> Window -> IO(Unit)) -> IO(Unit):
  (a, gs) = r
  do IO<Unit>:
    d : Window & Qs & Gs <- P3.present(win, qs, gs, mode)
    +t2 : U32 <- Clock.us()
    Unit <- IO.sleep(0)
    p3w.say(p3w.drop(d), hd, t0, t1, t2, w2 => k(a, w2))

def p3w.loop(+n: Nat, +cfg: Cfg, +mode: U32, a: Array<Glyph>, win: Window) -> IO(Unit):
  match n:
    case 0n:
      do IO<Unit>:
        Unit <- Window.close(win)
        finish(a)
    case 1n+p:
      Cfg{+cols, +rows, +w, +h, +frames, pace, m, blit, +g, check} = cfg
      +i = (frames - U32.from_nat(p) - 1 : U32)
      do IO<Unit>:
        +t0 : U32 <- Clock.us()
        qs : Qs <- IO.pure(Qs, scene(cols, rows, w, h, frame.ft(i)))
        r : Array<Glyph> & Gs <- IO.pure(Array<Glyph> & Gs, glyphs(g, w, h, a))
        +t1 : U32 <- Clock.us()
        p3w.step(r, qs, win, mode, "v p3w " ++ U32.show(mode) ++ " n " ++ U32.show((cols * rows : U32)) ++ " w " ++ U32.show(w) ++ " h " ++ U32.show(h) ++ " f " ++ U32.show(i),
          t0, t1, a2 => w2 => p3w.loop(p, cfg, mode, a2, w2))

def cfg.frames(c: Cfg) -> Nat:
  Cfg{cols, rows, w, h, frames, pace, m, blit, g, check} = c
  U32.to_nat(frames)

def p3w.go(shown: Window & Image & List<Event>, +cfg: Cfg, +mode: U32, a: Array<Glyph>) -> IO(Unit):
  (win, img, evs) = shown
  p3w.loop(cfg.frames(cfg), cfg, mode, a, win)

def p3w.run(+cfg: Cfg, +mode: U32) -> IO(Unit):
  Cfg{cols, rows, +w, +h, frames, pace, m, blit, g, check} = cfg
  do IO<Unit>:
    Unit <- IO.pure(Unit, Image.drop!(Pix{0}))
    win0 : Window <- IO.try(Window, Window.open("p3", (w / 2 : U32), (h / 2 : U32)))
    shown : Window & Image & List<Event> <- Window.frame(win0, Pix{0})
    a : Array<Glyph> <- IO.pure(Array<Glyph>, atlas())
    p3w.go(shown, cfg, mode, a)

def main() -> IO(Unit):
  do IO<Unit>:
    +cfg : Cfg <- config()
    +mode : U32 <- env("P3_MODE", 0)
    p3w.run(cfg, mode)
