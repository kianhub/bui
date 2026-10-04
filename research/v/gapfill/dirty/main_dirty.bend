# Gap 2: damage-tracked re-raster at 2x. The previous frame's Image quadtree
# is kept; a frame re-rasterizes only the 128-px cells (64-px at 1x) that
# intersect the dirty rect and moves every other subtree over unchanged
# (linear, no copy). Replaced cells are freed inside the update.
# Env: ui_common's (UI_MODE 1 = full redraw: host bin + dnode, as v/measure
# bin; UI_MODE 2 = incremental), UI_SCEN (0 static, 1 hover one card,
# 2 blinking caret, 3 one scrolling text column, 4 everything moves).

type DR is Data:
  DR{x0: U32, y0: U32, x1: U32, y1: U32}

def dhit(+d: DR, +x: U32, +y: U32, +s: U32) -> Bool:
  DR{+x0, +y0, +x1, +y1} = d
  ((x < x1) && ((x + s : U32) > x0) && (y < y1) && ((y + s : U32) > y0) : U32)

# a dirty cell, culled and flat-collapsed or rastered exactly as cbuild + dnode do
def cell.new(+qs: Qs, +gs: Gs, +x: U32, +y: U32, +big: Bool) -> Image:
  +s = csize(big)
  +la = boxq(qs, x, y, s)
  +ga = boxg(gs, x, y, s)
  +f = flat(la, Gs.empty(ga), x, y, s)
  node.go(2n, isflat(f), f, la, ga, x, y, big)

# k levels above the cells; qs/gs are culled to the parent's box
def upd(+k: Nat, hit: Bool, img: Image, +qs: Qs, +gs: Gs, +x: U32, +y: U32, +d: DR, +big: Bool) -> Image:
  match k hit img:
    case _ False{} _:
      img
    case 0n True{} _:
      cell.new(qs, gs, x, y, big)
    case 1n+e True{} Qua{ia, ib, ic, id}:
      +s = U32.shln(csize(big), e)
      +x1 = (x + s : U32)
      +y1 = (y + s : U32)
      +lq = boxq(qs, x, y, (s * 2 : U32))
      +lg = boxg(gs, x, y, (s * 2 : U32))
      ra rb rc rd = upd(e, dhit(d, x, y, s), ia, lq, lg, x, y, d, big)
        upd(e, dhit(d, x1, y, s), ib, lq, lg, x1, y, d, big)
        upd(e, dhit(d, x, y1, s), ic, lq, lg, x, y1, d, big)
        upd(e, dhit(d, x1, y1, s), id, lq, lg, x1, y1, d, big)
      Qua{ra, rb, rc, rd}
    case 1n+e True{} Pix{+col}:
      +s = U32.shln(csize(big), e)
      +x1 = (x + s : U32)
      +y1 = (y + s : U32)
      +lq = boxq(qs, x, y, (s * 2 : U32))
      +lg = boxg(gs, x, y, (s * 2 : U32))
      ra rb rc rd = upd(e, dhit(d, x, y, s), Pix{col}, lq, lg, x, y, d, big)
        upd(e, dhit(d, x1, y, s), Pix{col}, lq, lg, x1, y, d, big)
        upd(e, dhit(d, x, y1, s), Pix{col}, lq, lg, x, y1, d, big)
        upd(e, dhit(d, x1, y1, s), Pix{col}, lq, lg, x1, y1, d, big)
      Qua{ra, rb, rc, rd}

def root.s(+big: Bool) -> U32:
  U32.shln(csize(big), 5n)

def inc.go(+d: DR, prev: Image, qs: Qs, gs: Gs, +big: Bool) -> Image:
  upd!(5n, dhit(d, 0, 0, root.s(big)), prev, qs, gs, 0, 0, d, big)

# Scenarios
# ---------

def frame.ft(+i: U32) -> F32:
  (U32.to_f32(U32.and(i, 7)) * 0.5 : F32)

def none() -> U32:
  4294967295

def hcard(+cols: U32, +rows: U32) -> U32:
  ((rows / 2) * cols + cols / 2 : U32)

def scen.hi(+sc: U32, +i: U32, +cols: U32, +rows: U32) -> U32:
  word((U32.is_eq(sc, 1) && Bool.not(U32.is_even(i))), hcard(cols, rows), none())

def scen.car(+sc: U32, +i: U32) -> Bool:
  (U32.is_eq(sc, 2) && Bool.not(U32.is_even(i)))

def scen.off(+sc: U32, +i: U32) -> U32:
  word(U32.is_eq(sc, 3), ((i % 4) * 11 : U32), 0)

def scen.ft(+sc: U32, +i: U32) -> F32:
  pick(U32.is_eq(sc, 4), frame.ft(i), 0.0)

def caret.x(+w: U32) -> U32:
  ((20 + 40 * 10) * w / 1512 - 3 : U32)

def caret.y(+h: U32) -> U32:
  ((15 + 12 * 22) * h / 982 : U32)

def scene.of(+sc: U32, +i: U32, +cols: U32, +rows: U32, +w: U32, +h: U32) -> Qs:
  scene(cols, rows, w, h, scen.ft(sc, i), scen.hi(sc, i, cols, rows), scen.car(sc, i),
    U32.to_f32(caret.x(w)), U32.to_f32(caret.y(h)))

def fl(+v: F32) -> U32:
  F32.to_u32(F32.max(0.0, v))

def dirty.card(+cols: U32, +rows: U32, +w: U32, +h: U32) -> DR:
  +cw = ((U32.to_f32(w) - 16.0) / U32.to_f32(cols) : F32)
  +ch = ((U32.to_f32(h) - 16.0) / U32.to_f32(rows) : F32)
  +hc = hcard(cols, rows)
  +x0 = (U32.to_f32((hc % cols : U32)) * cw + 10.0 : F32)
  +y0 = (U32.to_f32((hc / cols : U32)) * ch + 10.0 : F32)
  DR{fl((x0 - 3.0 : F32)), fl((y0 - 3.0 : F32)), fl((x0 + cw : F32)), fl((y0 + ch : F32))}

def dirty.of(+sc: U32, +cols: U32, +rows: U32, +w: U32, +h: U32) -> DR:
  word.dr(U32.is_eq(sc, 1), dirty.card(cols, rows, w, h),
    word.dr(U32.is_eq(sc, 2), DR{(caret.x(w) - 3 : U32), (caret.y(h) - 3 : U32), (caret.x(w) + 6 : U32), (caret.y(h) + 36 : U32)},
      word.dr(U32.is_eq(sc, 3), DR{((20 + 30 * 10) * w / 1512 - 3 : U32), 0, ((20 + 39 * 10) * w / 1512 + 20 : U32), h},
        word.dr(U32.is_eq(sc, 4), DR{0, 0, w, h}, DR{0, 0, 0, 0}))))

def word.dr(c: Bool, a: DR, b: DR) -> DR:
  match c:
    case True{}:
      a
    case False{}:
      b

def dr.area(d: DR) -> U32:
  DR{x0, y0, x1, y1} = d
  ((x1 - x0) * (y1 - y0) : U32)

# Frame steps
# -----------

def full.cells(r: Array<Glyph> & Gs, qs: Qs, +big: Bool) -> Array<Glyph> & Cells:
  (a, gs) = r
  (a, cbuild(qs, gs, big))

def full.show(c: Array<Glyph> & Cells, +big: Bool) -> Array<Glyph> & Image & Cells:
  (a, cells) = c
  (a, cells.show(cells, big))

def full.fin(a: Array<Glyph>, img: Image, u: Unit) -> Array<Glyph> & Image:
  match u:
    case Unit{}:
      (a, img)

def full.split(d: Array<Glyph> & Image & Cells) -> Array<Glyph> & Image:
  (a, img, used) = d
  full.fin(a, img, cells.free(used))

# a full redraw (host binning, dnode bang), the previous image dropped after
def step.full(r: Array<Glyph> & Gs, qs: Qs, prev: Image, +big: Bool) -> IO(Array<Glyph> & Image & Image):
  do IO<Array<Glyph> & Image & Image>:
    c : Array<Glyph> & Cells <- IO.pure(Array<Glyph> & Cells, full.cells(r, qs, big))
    d : Array<Glyph> & Image & Cells <- IO.pure(Array<Glyph> & Image & Cells, full.show(c, big))
    IO.pure(Array<Glyph> & Image & Image, full.with(full.split(d), prev))

def full.with(d: Array<Glyph> & Image, prev: Image) -> Array<Glyph> & Image & Image:
  (a, img) = d
  (a, img, prev)

def inc.k(r: Array<Glyph> & Gs, qs: Qs, prev: Image, +d: DR, +big: Bool) -> Array<Glyph> & Image & Image:
  (a, gs) = r
  (a, inc.go(d, prev, qs, gs, big), Pix{0})

def step(full: Bool, r: Array<Glyph> & Gs, qs: Qs, prev: Image, +d: DR, +big: Bool) -> IO(Array<Glyph> & Image & Image):
  match full:
    case True{}:
      step.full(r, qs, prev, big)
    case False{}:
      IO.pure(Array<Glyph> & Image & Image, inc.k(r, qs, prev, d, big))

def show.k(s: Array<Glyph> & Image & Image, +w: U32, +h: U32, +k: U32) -> IO(Array<Glyph> & Image & Image):
  (a, img, old) = s
  do IO<Array<Glyph> & Image & Image>:
    shown : Image <- Blit.run(img, w, h, k)
    IO.pure(Array<Glyph> & Image & Image, (a, shown, old))

def drop.k(u: Unit, a: Array<Glyph>, img: Image) -> Array<Glyph> & Image:
  match u:
    case Unit{}:
      (a, img)

def drop.old(s: Array<Glyph> & Image & Image) -> Array<Glyph> & Image:
  (a, img, old) = s
  drop.k(Image.drop!(old), a, img)

def dsay(r: Array<Glyph> & Image, +hd: String, +t0: U32, +t1: U32, +t2: U32, +t3: U32, +t4: U32,
  k: Array<Glyph> -> Image -> IO(Unit)) -> IO(Unit):
  (a, img) = r
  do IO<Unit>:
    +rss : U32 <- Rss.kb()
    IO.print(hd ++ " build_us " ++ U32.show((t1 - t0 : U32)) ++ " render_us " ++ U32.show((t2 - t1 : U32))
      ++ " present_us " ++ U32.show((t3 - t2 : U32)) ++ " drop_us " ++ U32.show((t4 - t3 : U32))
      ++ " frame_us " ++ U32.show((t4 - t0 : U32)) ++ " rss_kb " ++ U32.show(rss))
    k(a, img)

# Check: the kept image against a full redraw of the last frame's scene
def check.sums(+s1: U32, img2: Image, +w: U32, +h: U32, +k: U32, a: Array<Glyph>) -> IO(Unit):
  do IO<Unit>:
    shown : Image <- Blit.run(img2, w, h, k)
    +s2 : U32 <- Blit.sum()
    IO.print("check incremental_blit_sum " ++ U32.show(s1) ++ " full_blit_sum " ++ U32.show(s2) ++ " equal " ++ Bool.show(U32.is_eq(s1, s2))
      ++ " full_leaves " ++ U32.show(leaves(shown)))
    finish(a)

def check.full(r: Array<Glyph> & Image & Image, +s1: U32, +w: U32, +h: U32, +k: U32) -> IO(Unit):
  (a, img, old) = r
  check.sums(s1, img, w, h, k, a)

def dfinish(+cfg: Cfg, +sc: U32, a: Array<Glyph>, prev: Image) -> IO(Unit):
  Cfg{+cols, +rows, +w, +h, +frames, pace, mode, blit, +g, check} = cfg
  +i = (frames - 1 : U32)
  +big = isbig(w, h)
  do IO<Unit>:
    shown : Image <- Blit.run(prev, w, h, root.k(w, h))
    +s1 : U32 <- Blit.sum()
    r : Array<Glyph> & Gs <- IO.pure(Array<Glyph> & Gs, glyphs(g, w, h, scen.off(sc, i), a))
    f : Array<Glyph> & Image & Image <- step.full(r, scene.of(sc, i, cols, rows, w, h), shown, big)
    check.full(f, s1, w, h, root.k(w, h))

def dloop(+n: Nat, +cfg: Cfg, +sc: U32, a: Array<Glyph>, prev: Image) -> IO(Unit):
  match n:
    case 0n:
      dfinish(cfg, sc, a, prev)
    case 1n+p:
      Cfg{+cols, +rows, +w, +h, +frames, pace, +mode, blit, +g, check} = cfg
      +i = (frames - U32.from_nat(p) - 1 : U32)
      +big = isbig(w, h)
      +d = dirty.of(sc, cols, rows, w, h)
      do IO<Unit>:
        +t0 : U32 <- Clock.us()
        qs : Qs <- IO.pure(Qs, scene.of(sc, i, cols, rows, w, h))
        r : Array<Glyph> & Gs <- IO.pure(Array<Glyph> & Gs, glyphs(g, w, h, scen.off(sc, i), a))
        +t1 : U32 <- Clock.us()
        s : Array<Glyph> & Image & Image <- step(U32.is_eq(mode, 1), r, qs, prev, d, big)
        +t2 : U32 <- Clock.us()
        s2 : Array<Glyph> & Image & Image <- show.k(s, w, h, root.k(w, h))
        +t3 : U32 <- Clock.us()
        r2 : Array<Glyph> & Image <- IO.pure(Array<Glyph> & Image, drop.old(s2))
        +t4 : U32 <- Clock.us()
        dsay(r2, "v " ++ U32.show(mode) ++ " sc " ++ U32.show(sc) ++ " n " ++ U32.show((cols * rows : U32)) ++ " w " ++ U32.show(w) ++ " h " ++ U32.show(h)
          ++ " f " ++ U32.show(i) ++ " dirty_px " ++ U32.show(dr.area(d)), t0, t1, t2, t3, t4, a2 => img2 => dloop(p, cfg, sc, a2, img2))

def first.k(r: Array<Glyph> & Image & Image) -> Array<Glyph> & Image:
  (a, img, old) = r
  (a, img)

def drun2(r: Array<Glyph> & Image, +cfg: Cfg, +sc: U32) -> IO(Unit):
  (a, img) = r
  dloop(cfg.frames(cfg), cfg, sc, a, img)

def cfg.frames(c: Cfg) -> Nat:
  Cfg{cols, rows, w, h, frames, pace, m, blit, g, check} = c
  U32.to_nat(frames)

def drun(+cfg: Cfg, +sc: U32) -> IO(Unit):
  Cfg{+cols, +rows, +w, +h, frames, pace, mode, blit, +g, check} = cfg
  do IO<Unit>:
    a : Array<Glyph> <- IO.pure(Array<Glyph>, atlas())
    r : Array<Glyph> & Gs <- IO.pure(Array<Glyph> & Gs, glyphs(g, w, h, 0, a))
    f : Array<Glyph> & Image & Image <- step.full(r, scene.of(0, 0, cols, rows, w, h), Pix{0}, isbig(w, h))
    drun2(first.k(f), cfg, sc)

def main() -> IO(Unit):
  do IO<Unit>:
    +cfg : Cfg <- config()
    +sc : U32 <- env("UI_SCEN", 1)
    drun(cfg, sc)

def Array.sink(-T: Type, a: Array<T>) -> Unit:
  Unit{}

def finish(a: Array<Glyph>) -> IO(Unit):
  do IO<Unit>:
    +rss : U32 <- Rss.kb()
    IO.print("done rss_kb " ++ U32.show(rss))
    IO.pure(Unit, Array.sink(Glyph, a))
