import Base

# A UI-shaped frame: a rounded panel, cols x rows rounded cards with 1-px
# borders, and G 8x16 alpha glyph sprites, rasterised into the Image
# quadtree Window.frame takes. The glyph atlas is an Array<Glyph> held on
# the host (96 glyphs, 16 row words of 8 x 4-bit alpha); the scene build
# copies each sprite's rows into its list entry, so the device walks flat
# lists of scalars (SHADERS.md's shape). Two rasterizers over one shading:
#   mode 0: culling inside the bang, root -> 16/32-px tiles, 7 fork levels
#   mode 1: host binning to cells (SHADERS.md): 5 host levels, 2 device levels
# A region whose top-most quad covers it flatly (past radius, border and the
# AA band) and which holds no glyph collapses to one Pix, as does an empty
# region. Lists are top-first; culls keep the order.
# Env: UI_COLS UI_ROWS UI_W UI_H UI_FRAMES UI_PACE(ms) UI_MODE UI_BLIT(0/1)
# UI_GLYPHS UI_CHECK(0/1).

def Clock.us() -> IO(U32):
  import "./clock.c"
  import "./clock.js"

def Rss.kb() -> IO(U32):
  import "./rss.c"
  import "./rss.js"

def Blit.run(image: Image, w: U32, h: U32, k: U32) -> IO(Image):
  import "./blit.c"
  import "./blit.js"

def Blit.pick(x: U32, y: U32) -> IO(U32):
  import "./blit.c"
  import "./blit.js"

def Blit.sum() -> IO(U32):
  import "./blit.c"
  import "./blit.js"

# Scalars
# -------

def pick(c: Bool, a: F32, b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

def word(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def fmin(+a: F32, +b: F32) -> F32:
  pick((a < b : F32), a, b)

def fmax(+a: F32, +b: F32) -> F32:
  pick((a < b : F32), b, a)

def sat(+x: F32) -> F32:
  fmin(1.0, fmax(0.0, x))

def sdf(+px: F32, +py: F32, +cx: F32, +cy: F32, +hw: F32, +hh: F32, +r: F32) -> F32:
  +qx = (F32.abs((px - cx : F32)) - hw + r : F32)
  +qy = (F32.abs((py - cy : F32)) - hh + r : F32)
  +ox = fmax(qx, 0.0)
  +oy = fmax(qy, 0.0)
  (F32.sqrt((ox * ox + oy * oy : F32)) + fmin(fmax(qx, qy), 0.0) - r : F32)

def rsdf(+px: F32, +py: F32, +x0: F32, +y0: F32, +x1: F32, +y1: F32, +r: F32) -> F32:
  +hw = ((x1 - x0) * 0.5 : F32)
  +hh = ((y1 - y0) * 0.5 : F32)
  sdf(px, py, (x0 + hw : F32), (y0 + hh : F32), hw, hh, r)

def cov(+d: F32) -> F32:
  sat((0.5 - d : F32))

def pack(+r: F32, +g: F32, +b: F32) -> U32:
  (F32.to_u32((255.0 * sat(r) : F32)) << 16n
    .|. F32.to_u32((255.0 * sat(g) : F32)) << 8n
    .|. F32.to_u32((255.0 * sat(b) : F32)) : U32)

def chan(+c: U32, +sh: Nat) -> F32:
  (U32.to_f32(U32.and(U32.shrn(c, sh), 255)) * 0.003921569 : F32)

def bg() -> U32:
  pack(0.10, 0.11, 0.13)

# Scene
# -----

type Qs is Data:
  QNil{}
  QCons{x0: F32, y0: F32, x1: F32, y1: F32, r: F32, bw: F32, fc: U32, bc: U32, next: Qs}

# a glyph: 16 rows of 8 texels, 4 bits of alpha each
type Cells is Data:
  CNil{}
  CPix{c: U32}
  CLeaf{ts: Qs, gs: Gs}
  CQua{tl: Cells, tr: Cells, bl: Cells, br: Cells}

def Qs.sink(ts: Qs) -> Unit:
  match ts:
    case QNil{}:
      Unit{}
    case QCons{_, _, _, _, _, _, _, _, next}:
      Qs.sink(next)

# Shading, front to back: glyphs first, then quads; t is the light left.
# ----------------------------------------------------------------------

# the row word of a glyph for dy in 0..15
# the 4-bit alpha of texel dx in 0..7 of a row word
def px.q(ts: Qs, +px: F32, +py: F32, +cr: F32, +cg: F32, +cb: F32, +t: F32) -> U32:
  match ts:
    case QNil{}:
      pack((cr + t * 0.10 : F32), (cg + t * 0.11 : F32), (cb + t * 0.13 : F32))
    case QCons{+x0, +y0, +x1, +y1, +r, +bw, +fc, +bc, next}:
      +d = rsdf(px, py, x0, y0, x1, y1, r)
      +ao = (cov(d) * t : F32)
      +ai = (cov((d + bw : F32)) * t : F32)
      +ab = (ao - ai : F32)
      px.q(next, px, py, (cr + ai * chan(fc, 16n) + ab * chan(bc, 16n) : F32),
        (cg + ai * chan(fc, 8n) + ab * chan(bc, 8n) : F32),
        (cb + ai * chan(fc, 0n) + ab * chan(bc, 0n) : F32), (t - ao : F32))

def px(+ts: Qs, +gs: Gs, +x: U32, +y: U32) -> U32:
  px.sp(gs, x, y, (U32.to_f32(x) + 0.5 : F32), (U32.to_f32(y) + 0.5 : F32), ts, 0.0, 0.0, 0.0, 1.0)

def blk.mk(same: Bool, +c0: U32, +c1: U32, +c2: U32, +c3: U32) -> Image:
  match same:
    case True{}:
      Pix{c0}
    case False{}:
      Qua{Pix{c0}, Pix{c1}, Pix{c2}, Pix{c3}}

def blk(+ts: Qs, +gs: Gs, +x: U32, +y: U32) -> Image:
  +x1 = (x + 1 : U32)
  +y1 = (y + 1 : U32)
  +c0 = px(ts, gs, x, y)
  +c1 = px(ts, gs, x1, y)
  +c2 = px(ts, gs, x, y1)
  +c3 = px(ts, gs, x1, y1)
  blk.mk((U32.is_eq(c0, c1) && U32.is_eq(c1, c2) && U32.is_eq(c2, c3)), c0, c1, c2, c3)

def t4(+ts: Qs, +gs: Gs, +x: U32, +y: U32) -> Image:
  +x1 = (x + 2 : U32)
  +y1 = (y + 2 : U32)
  Qua{blk(ts, gs, x, y), blk(ts, gs, x1, y), blk(ts, gs, x, y1), blk(ts, gs, x1, y1)}

def t8(+ts: Qs, +gs: Gs, +x: U32, +y: U32) -> Image:
  +x1 = (x + 4 : U32)
  +y1 = (y + 4 : U32)
  Qua{t4(ts, gs, x, y), t4(ts, gs, x1, y), t4(ts, gs, x, y1), t4(ts, gs, x1, y1)}

def t16(+ts: Qs, +gs: Gs, +x: U32, +y: U32) -> Image:
  +x1 = (x + 8 : U32)
  +y1 = (y + 8 : U32)
  Qua{t8(ts, gs, x, y), t8(ts, gs, x1, y), t8(ts, gs, x, y1), t8(ts, gs, x1, y1)}

def t32(+ts: Qs, +gs: Gs, +x: U32, +y: U32) -> Image:
  +x1 = (x + 16 : U32)
  +y1 = (y + 16 : U32)
  Qua{t16(ts, gs, x, y), t16(ts, gs, x1, y), t16(ts, gs, x, y1), t16(ts, gs, x1, y1)}

# the tile's lists freed after its pixels read them
def tile.fin(img: Image, u: Unit, v: Unit) -> Image:
  match u v:
    case Unit{} Unit{}:
      img

def tile(+ts: Qs, +gs: Gs, +x: U32, +y: U32, big: Bool) -> Image:
  match big:
    case False{}:
      tile.fin(t16(ts, gs, x, y), Qs.sink(ts), Gs.sink(gs))
    case True{}:
      tile.fin(t32(ts, gs, x, y), Qs.sink(ts), Gs.sink(gs))

# Culling (order kept: reverse-accumulate, then reverse) and flatness
# -------------------------------------------------------------------

def keepq(on: Bool, +x0: F32, +y0: F32, +x1: F32, +y1: F32, +r: F32, +bw: F32, +fc: U32, +bc: U32, acc: Qs) -> Qs:
  match on:
    case True{}:
      QCons{x0, y0, x1, y1, r, bw, fc, bc, acc}
    case False{}:
      acc

def cullq(qs: Qs, +bx0: F32, +by0: F32, +bx1: F32, +by1: F32, acc: Qs) -> Qs:
  match qs:
    case QNil{}:
      acc
    case QCons{+x0, +y0, +x1, +y1, +r, +bw, +fc, +bc, next}:
      cullq(next, bx0, by0, bx1, by1,
        keepq(((x0 < bx1) && (x1 > bx0) && (y0 < by1) && (y1 > by0) : F32), x0, y0, x1, y1, r, bw, fc, bc, acc))

def revq(qs: Qs, acc: Qs) -> Qs:
  match qs:
    case QNil{}:
      acc
    case QCons{+x0, +y0, +x1, +y1, +r, +bw, +fc, +bc, next}:
      revq(next, QCons{x0, y0, x1, y1, r, bw, fc, bc, acc})

def boxq(+qs: Qs, +x: U32, +y: U32, +s: U32) -> Qs:
  revq(cullq(qs, (U32.to_f32(x) - 1.0 : F32), (U32.to_f32(y) - 1.0 : F32),
    (U32.to_f32((x + s : U32)) + 1.0 : F32), (U32.to_f32((y + s : U32)) + 1.0 : F32), QNil{}), QNil{})

# 4294967295 when the region is not flat; else its one colour. A region
# is flat when it holds no glyph and either no quad, or its top quad's inner
# rect (inset by radius + border + AA) contains the region box.
def flat.q(qs: Qs, +x: F32, +y: F32, +x1: F32, +y1: F32) -> U32:
  match qs:
    case QNil{}:
      bg()
    case QCons{+qx0, +qy0, +qx1, +qy1, +r, +bw, +fc, +bc, next}:
      +m = (fmax(r, bw) + 1.5 : F32)
      word((((qx0 + m) <= x) && ((qy0 + m) <= y) && ((qx1 - m) >= x1) && ((qy1 - m) >= y1) : F32),
        pack(chan(fc, 16n), chan(fc, 8n), chan(fc, 0n)), 4294967295)

def flat(+qs: Qs, nog: Bool, +x: U32, +y: U32, +s: U32) -> U32:
  match nog:
    case False{}:
      4294967295
    case True{}:
      flat.q(qs, (U32.to_f32(x) - 1.0 : F32), (U32.to_f32(y) - 1.0 : F32),
        (U32.to_f32((x + s : U32)) + 1.0 : F32), (U32.to_f32((y + s : U32)) + 1.0 : F32))

def isflat(+c: U32) -> Bool:
  U32.is_ne(c, 4294967295)

def tsize(big: Bool) -> U32:
  match big:
    case False{}:
      16
    case True{}:
      32

def csize(big: Bool) -> U32:
  match big:
    case False{}:
      64
    case True{}:
      128

# Device tree (both modes): owned lists, freed after their culls
# ---------------------------------------------------------------

def node.flat(+fc: U32, u: Unit, v: Unit) -> Image:
  match u v:
    case Unit{} Unit{}:
      Pix{fc}

def node.go(+k: Nat, isf: Bool, +fc: U32, +qs: Qs, +gs: Gs, +x: U32, +y: U32, +big: Bool) -> Image:
  match k isf:
    case _ True{}:
      node.flat(fc, Qs.sink(qs), Gs.sink(gs))
    case 0n False{}:
      tile(qs, gs, x, y, big)
    case 1n+e False{}:
      +s = U32.shln(tsize(big), e)
      +x1 = (x + s : U32)
      +y1 = (y + s : U32)
      +la = boxq(qs, x, y, s)
      +lb = boxq(qs, x1, y, s)
      +lc = boxq(qs, x, y1, s)
      +ld = boxq(qs, x1, y1, s)
      +ga = boxg(gs, x, y, s)
      +gb = boxg(gs, x1, y, s)
      +gc = boxg(gs, x, y1, s)
      +gd = boxg(gs, x1, y1, s)
      _ = qs
      _ = gs
      +fa = flat(la, Gs.empty(ga), x, y, s)
      +fb = flat(lb, Gs.empty(gb), x1, y, s)
      +fc2 = flat(lc, Gs.empty(gc), x, y1, s)
      +fd = flat(ld, Gs.empty(gd), x1, y1, s)
      a b c d = node.go(e, isflat(fa), fa, la, ga, x, y, big)
        node.go(e, isflat(fb), fb, lb, gb, x1, y, big)
        node.go(e, isflat(fc2), fc2, lc, gc, x, y1, big)
        node.go(e, isflat(fd), fd, ld, gd, x1, y1, big)
      Qua{a, b, c, d}

# mode 0: the whole tree in one bang; the host's lists are owned by the bang
def frame.show(qs: Qs, gs: Gs, +big: Bool) -> Image:
  node.go!(7n, False{}, 0, qs, gs, 0, 0, big)

# mode 1, device at a cell: the host's lists, only read
def cell.top(+ts: Qs, +gs: Gs, +x: U32, +y: U32, +big: Bool) -> Image:
  +s = U32.shln(tsize(big), 1n)
  +x1 = (x + s : U32)
  +y1 = (y + s : U32)
  +la = boxq(ts, x, y, s)
  +lb = boxq(ts, x1, y, s)
  +lc = boxq(ts, x, y1, s)
  +ld = boxq(ts, x1, y1, s)
  +ga = boxg(gs, x, y, s)
  +gb = boxg(gs, x1, y, s)
  +gc = boxg(gs, x, y1, s)
  +gd = boxg(gs, x1, y1, s)
  +fa = flat(la, Gs.empty(ga), x, y, s)
  +fb = flat(lb, Gs.empty(gb), x1, y, s)
  +fc2 = flat(lc, Gs.empty(gc), x, y1, s)
  +fd = flat(ld, Gs.empty(gd), x1, y1, s)
  a b c d = node.go(1n, isflat(fa), fa, la, ga, x, y, big)
    node.go(1n, isflat(fb), fb, lb, gb, x1, y, big)
    node.go(1n, isflat(fc2), fc2, lc, gc, x, y1, big)
    node.go(1n, isflat(fd), fd, ld, gd, x1, y1, big)
  Qua{a, b, c, d}

def dnode(+k: Nat, c: Cells, +x: U32, +y: U32, +big: Bool) -> Image:
  match k c:
    case _ CNil{}:
      Pix{bg()}
    case _ CPix{+col}:
      Pix{col}
    case _ CLeaf{ts, gs}:
      cell.top(ts, gs, x, y, big)
    case 1n+e CQua{tl, tr, bl, br}:
      +s = U32.shln(csize(big), e)
      +x1 = (x + s : U32)
      +y1 = (y + s : U32)
      a b c d = dnode(e, tl, x, y, big) dnode(e, tr, x1, y, big) dnode(e, bl, x, y1, big) dnode(e, br, x1, y1, big)
      Qua{a, b, c, d}
    case 0n CQua{tl, tr, bl, br}:
      Pix{0}

# the bang borrows the cells and hands them back to the host
def cells.show(+cells: Cells, +big: Bool) -> Image & Cells:
  (dnode!(5n, cells, 0, 0, big), cells)

# Host binning (mode 1): the lists culled down a quadtree to cells
# -----------------------------------------------------------------

def cells.flat(+fc: U32, u: Unit, v: Unit) -> Cells:
  match u v:
    case Unit{} Unit{}:
      CPix{fc}

def cbuild.go(+k: Nat, isf: Bool, +fc: U32, +qs: Qs, +gs: Gs, +x: U32, +y: U32, +big: Bool) -> Cells:
  match k isf:
    case _ True{}:
      cells.flat(fc, Qs.sink(qs), Gs.sink(gs))
    case 0n False{}:
      CLeaf{qs, gs}
    case 1n+e False{}:
      +s = U32.shln(csize(big), e)
      +x1 = (x + s : U32)
      +y1 = (y + s : U32)
      +la = boxq(qs, x, y, s)
      +lb = boxq(qs, x1, y, s)
      +lc = boxq(qs, x, y1, s)
      +ld = boxq(qs, x1, y1, s)
      +ga = boxg(gs, x, y, s)
      +gb = boxg(gs, x1, y, s)
      +gc = boxg(gs, x, y1, s)
      +gd = boxg(gs, x1, y1, s)
      _ = qs
      _ = gs
      +fa = flat(la, Gs.empty(ga), x, y, s)
      +fb = flat(lb, Gs.empty(gb), x1, y, s)
      +fc2 = flat(lc, Gs.empty(gc), x, y1, s)
      +fd = flat(ld, Gs.empty(gd), x1, y1, s)
      a b c d = cbuild.go(e, isflat(fa), fa, la, ga, x, y, big)
        cbuild.go(e, isflat(fb), fb, lb, gb, x1, y, big)
        cbuild.go(e, isflat(fc2), fc2, lc, gc, x, y1, big)
        cbuild.go(e, isflat(fd), fd, ld, gd, x1, y1, big)
      CQua{a, b, c, d}

def cbuild(qs: Qs, gs: Gs, +big: Bool) -> Cells:
  cbuild.go(5n, False{}, 0, qs, gs, 0, 0, big)

# Scene build (host)
# ------------------

def cards(+n: Nat, +i: U32, +cols: U32, +cw: F32, +ch: F32, +ft: F32, +hi: U32, acc: Qs) -> Qs:
  match n:
    case 0n:
      acc
    case 1n+p:
      +col = (i % cols : U32)
      +row = (i / cols : U32)
      +x0 = (U32.to_f32(col) * cw + 10.0 + ft : F32)
      +y0 = (U32.to_f32(row) * ch + 10.0 : F32)
      cards(p, (i + 1 : U32), cols, cw, ch, ft, hi,
        QCons{x0, y0, (x0 + cw - 4.0 : F32), (y0 + ch - 4.0 : F32), 4.0, 1.0,
          word(U32.is_eq(i, hi), 16777215, U32.or(U32.and((i * 2654435761 : U32), 16777215), 4210752)), 10526880, acc})

# top-first: [caret], the cards, then the panel at the tail (bottom-most)
def caret(on: Bool, +x: F32, +y: F32, +h: F32, rest: Qs) -> Qs:
  match on:
    case True{}:
      QCons{x, y, (x + 2.0 : F32), (y + h : F32), 0.0, 0.0, 16777215, 16777215, rest}
    case False{}:
      rest

def scene(+cols: U32, +rows: U32, +w: U32, +h: U32, +ft: F32, +hi: U32, car: Bool, +cx: F32, +cy: F32) -> Qs:
  +fw = U32.to_f32(w)
  +fh = U32.to_f32(h)
  caret(car, cx, cy, 32.0, cards(U32.to_nat((cols * rows : U32)), 0, cols,
    ((fw - 16.0) / U32.to_f32(cols) : F32), ((fh - 16.0) / U32.to_f32(rows) : F32), ft, hi,
    QCons{8.0, 8.0, (fw - 8.0 : F32), (fh - 8.0 : F32), 12.0, 2.0, 2763059, 4473935, QNil{}}))

# Validation
# ----------

def span(+a: U32, +s: U32, +lim: U32) -> U32:
  U32.min(s, (lim - U32.min(a, lim) : U32))

def isum(img: Image, +s: U32, +x: U32, +y: U32, +w: U32, +h: U32) -> U32:
  match img:
    case Pix{c}:
      (c * span(x, s, w) * span(y, s, h) : U32)
    case Qua{a, b, c, d}:
      +hs = U32.shr(s)
      +x1 = (x + hs : U32)
      +y1 = (y + hs : U32)
      (isum(a, hs, x, y, w, h) + isum(b, hs, x1, y, w, h) + isum(c, hs, x, y1, w, h) + isum(d, hs, x1, y1, w, h) : U32)

def leaves(img: Image) -> U32:
  match img:
    case Pix{c}:
      1
    case Qua{a, b, c, d}:
      (leaves(a) + leaves(b) + leaves(c) + leaves(d) : U32)

# Config
# ------

type Cfg is Data:
  Cfg{cols: U32, rows: U32, w: U32, h: U32, frames: U32, pace: U32, mode: U32, blit: U32, glyphs: U32, check: U32}

def Env.u32(m: Maybe<&2, U32>, +default: U32) -> U32:
  match m:
    case None{}:
      default
    case Some{v}:
      v

def Env.num(r: Result<&1, &1, U32 & String, String>, +default: U32) -> U32:
  match r:
    case Fail{_}:
      default
    case Done{text}:
      Env.u32(U32.read(text), default)

def env(name: String, +default: U32) -> IO(U32):
  do IO<U32>:
    r : Result<&1, &1, U32 & String, String> <- IO.get_env(name)
    IO.pure(U32, Env.num(r, default))

def config() -> IO(Cfg):
  do IO<Cfg>:
    +cols : U32 <- env("UI_COLS", 16)
    +rows : U32 <- env("UI_ROWS", 16)
    +w : U32 <- env("UI_W", 1920)
    +h : U32 <- env("UI_H", 1200)
    +frames : U32 <- env("UI_FRAMES", 40)
    +pace : U32 <- env("UI_PACE", 0)
    +mode : U32 <- env("UI_MODE", 0)
    +blit : U32 <- env("UI_BLIT", 1)
    +glyphs : U32 <- env("UI_GLYPHS", 2000)
    +check : U32 <- env("UI_CHECK", 0)
    IO.pure(Cfg, Cfg{cols, rows, w, h, frames, pace, mode, blit, glyphs, check})

def root.k(+w: U32, +h: U32) -> U32:
  word(((w < 2049) && (h < 2049) : U32), 11, 12)

def isbig(+w: U32, +h: U32) -> Bool:
  U32.is_eq(root.k(w, h), 12)

# Frame steps
# -----------

def tile.unit(u: Unit, v: Unit) -> Unit:
  match u v:
    case Unit{} Unit{}:
      Unit{}

def cells.join(a: Unit, b: Unit, c: Unit, d: Unit) -> Unit:
  match a b c d:
    case Unit{} Unit{} Unit{} Unit{}:
      Unit{}

def cells.free(c: Cells) -> Unit:
  match c:
    case CNil{}:
      Unit{}
    case CPix{_}:
      Unit{}
    case CLeaf{ts, gs}:
      tile.unit(Qs.sink(ts), Gs.sink(gs))
    case CQua{a, b, c, d}:
      cells.join(cells.free(a), cells.free(b), cells.free(c), cells.free(d))

