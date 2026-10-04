# Gap 3 driver: the Bend side builds ui_common's Scene (N cards as Qs, G
# glyph sprites as Gs) on the host each frame; P3.draw (p3.c) renders it on
# the GPU reading the lists in place from the Bend heap.
# Env: ui_common's, plus P3_MODE (0 raster pipeline, 1 compute quads only,
# 2 compute quads + glyphs), P3_BANG (1: run the bang raster + Blit present +
# Image.drop! in the same frame before P3, sharing gpu_dev/queue/heap with it).

def P3.draw(qs: Qs, gs: Gs, w: U32, h: U32, mode: U32) -> IO(Qs & Gs):
  import "./p3fx.c"
  import "./p3fx.js"

def P3.dump(k: U32) -> IO(U32):
  import "./p3fx.c"
  import "./p3fx.js"

def P3.present(win: Window, qs: Qs, gs: Gs, mode: U32) -> IO(Window & Qs & Gs):
  import "./p3fx.c"
  import "./p3fx.js"

def Blit.dump(k: U32) -> IO(U32):
  import "./blit.c"
  import "./blit.js"

def p3.drop(r: Qs & Gs) -> Unit:
  (qs, gs) = r
  tile.unit(Qs.sink(qs), Gs.sink(gs))

def p3.say(+hd: String, +t0: U32, +t1: U32, +t2: U32, +t3: U32, k: IO(Unit)) -> IO(Unit):
  do IO<Unit>:
    IO.print(hd ++ " build_us " ++ U32.show((t1 - t0 : U32)) ++ " draw_us " ++ U32.show((t2 - t1 : U32))
      ++ " drop_us " ++ U32.show((t3 - t2 : U32)) ++ " frame_us " ++ U32.show((t3 - t0 : U32)))
    k

def p3.step(r: Array<Glyph> & Gs, qs: Qs, +w: U32, +h: U32, +mode: U32, +hd: String, +t0: U32, +t1: U32,
  k: Array<Glyph> -> IO(Unit)) -> IO(Unit):
  (a, gs) = r
  do IO<Unit>:
    d : Qs & Gs <- P3.draw(qs, gs, w, h, mode)
    +t2 : U32 <- Clock.us()
    Unit <- IO.pure(Unit, p3.drop(d))
    +t3 : U32 <- Clock.us()
    p3.say(hd, t0, t1, t2, t3, k(a))

def drop.k(r: Array<Glyph> & U32) -> Array<Glyph>:
  (a, t) = r
  a

# optional: the Bend raster of the same frame (bin mode, bang) + Blit + drop, first
def bang.pre(on: Bool, +cols: U32, +rows: U32, +w: U32, +h: U32, +g: U32, +ft: F32, a: Array<Glyph>, +big: Bool) -> IO(Array<Glyph>):
  match on:
    case False{}:
      IO.pure(Array<Glyph>, a)
    case True{}:
      do IO<Array<Glyph>>:
        d : Array<Glyph> & Image & U32 <- draw(True{}, cols, rows, w, h, g, ft, a, big)
        s : Array<Glyph> & Image & U32 <- present(True{}, d, w, h, root.k(w, h))
        r : Array<Glyph> & U32 <- IO.pure(Array<Glyph> & U32, drop.go(s))
        IO.pure(Array<Glyph>, drop.k(r))

def p3.loop(+n: Nat, +cfg: Cfg, +mode: U32, +pre: U32, a0: Array<Glyph>) -> IO(Unit):
  match n:
    case 0n:
      finish(a0)
    case 1n+p:
      Cfg{+cols, +rows, +w, +h, +frames, pace, m, blit, +g, check} = cfg
      +i = (frames - U32.from_nat(p) - 1 : U32)
      +ft = frame.ft(i)
      do IO<Unit>:
        a : Array<Glyph> <- bang.pre(U32.is_eq(pre, 1), cols, rows, w, h, g, ft, a0, isbig(w, h))
        +t0 : U32 <- Clock.us()
        qs : Qs <- IO.pure(Qs, scene(cols, rows, w, h, ft))
        r : Array<Glyph> & Gs <- IO.pure(Array<Glyph> & Gs, glyphs(g, w, h, a))
        +t1 : U32 <- Clock.us()
        p3.step(r, qs, w, h, mode, "v p3 " ++ U32.show(mode) ++ " n " ++ U32.show((cols * rows : U32)) ++ " w " ++ U32.show(w) ++ " h " ++ U32.show(h) ++ " f " ++ U32.show(i),
          t0, t1, a2 => p3.loop(p, cfg, mode, pre, a2))

# check: frame 7 drawn by the Bend raster (bin mode) and Blit, and by P3; both textures dumped
def p3.check(+cfg: Cfg, +mode: U32, a: Array<Glyph>, k: Array<Glyph> -> IO(Unit)) -> IO(Unit):
  Cfg{+cols, +rows, +w, +h, frames, pace, m, blit, +g, check} = cfg
  do IO<Unit>:
    d : Array<Glyph> & Image & U32 <- draw(True{}, cols, rows, w, h, g, frame.ft(7), a, isbig(w, h))
    s : Array<Glyph> & Image & U32 <- present(True{}, d, w, h, root.k(w, h))
    +b : U32 <- Blit.dump(7)
    r : Array<Glyph> & U32 <- IO.pure(Array<Glyph> & U32, drop.go(s))
    p3.check2(drop.k(r), cfg, mode, k)

def p3.check2(a: Array<Glyph>, +cfg: Cfg, +mode: U32, k: Array<Glyph> -> IO(Unit)) -> IO(Unit):
  Cfg{+cols, +rows, +w, +h, frames, pace, m, blit, +g, check} = cfg
  p3.check3(glyphs(g, w, h, a), scene(cols, rows, w, h, frame.ft(7)), w, h, mode, k)

def p3.check3(r: Array<Glyph> & Gs, qs: Qs, +w: U32, +h: U32, +mode: U32, k: Array<Glyph> -> IO(Unit)) -> IO(Unit):
  (a, gs) = r
  do IO<Unit>:
    d : Qs & Gs <- P3.draw(qs, gs, w, h, mode)
    +x : U32 <- P3.dump(7)
    Unit <- IO.pure(Unit, p3.drop(d))
    IO.print("check dumped blit_7.raw and p3_7.raw")
    k(a)

def p3.run(+cfg: Cfg, +mode: U32, +pre: U32) -> IO(Unit):
  Cfg{cols, rows, w, h, +frames, pace, m, blit, g, +check} = cfg
  do IO<Unit>:
    Unit <- IO.pure(Unit, Image.drop!(Pix{0}))
    a : Array<Glyph> <- IO.pure(Array<Glyph>, atlas())
    p3.go(U32.is_eq(check, 1), cfg, mode, pre, a)

def cfg.frames(c: Cfg) -> Nat:
  Cfg{cols, rows, w, h, frames, pace, m, blit, g, check} = c
  U32.to_nat(frames)

def p3.go(on: Bool, +cfg: Cfg, +mode: U32, +pre: U32, a: Array<Glyph>) -> IO(Unit):
  match on:
    case False{}:
      p3.loop(cfg.frames(cfg), cfg, mode, pre, a)
    case True{}:
      p3.check(cfg, mode, a, a2 => p3.loop(cfg.frames(cfg), cfg, mode, pre, a2))

def main() -> IO(Unit):
  do IO<Unit>:
    +cfg : Cfg <- config()
    +mode : U32 <- env("P3_MODE", 0)
    +pre : U32 <- env("P3_BANG", 0)
    p3.run(cfg, mode, pre)
