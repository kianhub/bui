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
type GT is Data:
  GL{a: U32, b: U32, c: U32, d: U32}
  GN{lo: GT, hi: GT}

type Gs is Data:
  GNil{}
  GCons{sx: U32, sy: U32, c: U32, g: GT, next: Gs}

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

def gpick(b: Bool, lo: GT, hi: GT) -> GT:
  match b:
    case True{}:
      hi
    case False{}:
      lo

def gbit(+dy: U32, +p: Nat) -> Bool:
  U32.is_eq(U32.and(U32.shrn(dy, p), 1), 1)

def byte4(+dx: U32, +w: U32) -> U32:
  +q = U32.and(dx, 3)
  U32.and(word((q < 2 : U32), word((q < 1 : U32), w, (w >> 8n : U32)), word((q < 3 : U32), (w >> 16n : U32), (w >> 24n : U32))), 255)

def gt.tex(+lvl: Nat, t: GT, +dy: U32, +dx: U32) -> U32:
  match lvl t:
    case _ GL{+a, +b, +c, +d}:
      byte4(dx, word((dx < 8 : U32), word((dx < 4 : U32), a, b), word((dx < 12 : U32), c, d)))
    case 0n GN{lo, hi}:
      0
    case 1n+p GN{lo, hi}:
      gt.tex(p, gpick(gbit(dy, p), lo, hi), dy, dx)

def alpha8(inside: Bool, g: GT, +dx: U32, +dy: U32) -> F32:
  match inside:
    case False{}:
      0.0
    case True{}:
      (U32.to_f32(gt.tex(5n, g, dy, dx)) * 0.003921569 : F32)

def px.sp(gs: Gs, +x: U32, +y: U32, +px: F32, +py: F32, +ts: Qs, +cr: F32, +cg: F32, +cb: F32, +t: F32) -> U32:
  match gs:
    case GNil{}:
      px.q(ts, px, py, cr, cg, cb, t)
    case GCons{+sx, +sy, +c, +g, next}:
      +dx = (x - sx : U32)
      +dy = (y - sy : U32)
      +al = alpha8(((dx < 16) && (dy < 32) : U32), g, dx, dy)
      +av = (al * t : F32)
      px.sp(next, x, y, px, py, ts, (cr + av * chan(c, 16n) : F32), (cg + av * chan(c, 8n) : F32),
        (cb + av * chan(c, 0n) : F32), (t - av : F32))

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

def Gs.sink(gs: Gs) -> Unit:
  match gs:
    case GNil{}:
      Unit{}
    case GCons{_, _, _, _, next}:
      Gs.sink(next)

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

def Gs.empty(gs: Gs) -> Bool:
  match gs:
    case GNil{}:
      True{}
    case GCons{_, _, _, _, _}:
      False{}

def keepg(on: Bool, +sx: U32, +sy: U32, +c: U32, +g: GT, acc: Gs) -> Gs:
  match on:
    case True{}:
      GCons{sx, sy, c, g, acc}
    case False{}:
      acc

def cullg(gs: Gs, +x: U32, +y: U32, +x1: U32, +y1: U32, acc: Gs) -> Gs:
  match gs:
    case GNil{}:
      acc
    case GCons{+sx, +sy, +c, +g, next}:
      cullg(next, x, y, x1, y1,
        keepg(((sx < x1) && (x < (sx + 16 : U32)) && (sy < y1) && (y < (sy + 32 : U32)) : U32), sx, sy, c, g, acc))

def revg(gs: Gs, acc: Gs) -> Gs:
  match gs:
    case GNil{}:
      acc
    case GCons{+sx, +sy, +c, +g, next}:
      revg(next, GCons{sx, sy, c, g, acc})

def boxg(+gs: Gs, +x: U32, +y: U32, +s: U32) -> Gs:
  revg(cullg(gs, x, y, (x + s : U32), (y + s : U32), GNil{}), GNil{})

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

# 2x glyphs: 16 x 32 texels of 8-bit coverage. A glyph is a balanced tree of
# its 32 rows (GT, depth 5), each row 4 words of 4 texels; the atlas holds 96
# of them and a sprite shares its glyph's tree (a refcounted reference, as a
# GPU sprite references an atlas tile) instead of copying texels.
type Glyph is Data:
  Glyph{t: GT}

# texel (0..255) at row dy, column dx of a glyph tree of depth lvl
# atlas: 96 glyph trees; texel coverage from a hash (about 43% solid, 16% partial)
def texel(+g: U32, +dy: U32, +dx: U32) -> U32:
  +v = U32.shrn(((g + 1) * 2654435761 + dy * 1013904223 + dx * 3932081 : U32), 24n)
  word((v < 110 : U32), 255, word((v < 150 : U32), ((v - 110) * 6 : U32), 0))

def row.w(+g: U32, +dy: U32, +x0: U32) -> U32:
  (texel(g, dy, x0) .|. texel(g, dy, (x0 + 1 : U32)) << 8n .|. texel(g, dy, (x0 + 2 : U32)) << 16n
    .|. texel(g, dy, (x0 + 3 : U32)) << 24n : U32)

def gt.mk(+lvl: Nat, +g: U32, +dy: U32) -> GT:
  match lvl:
    case 0n:
      GL{row.w(g, dy, 0), row.w(g, dy, 4), row.w(g, dy, 8), row.w(g, dy, 12)}
    case 1n+p:
      GN{gt.mk(p, g, dy), gt.mk(p, g, (dy + U32.shln(1, p) : U32))}

def glyph.mk(+g: U32) -> Glyph:
  Glyph{gt.mk(5n, g, 0)}

def atlas.fill(n: Nat, a: Array<Glyph>, +i: U32) -> Array<Glyph>:
  match n:
    case 0n:
      a
    case 1n+p:
      atlas.fill(p, Array.set(Glyph, a, i, glyph.mk(i)), (i + 1 : U32))

def atlas() -> Array<Glyph>:
  atlas.fill(96n, [{Glyph{GL{0, 0, 0, 0}} : Glyph} : Glyph^7n], 0)

def sprite.mk(r: Array<Glyph> & Glyph, +sx: U32, +sy: U32, +c: U32, acc: Gs) -> Array<Glyph> & Gs:
  (a, gl) = r
  Glyph{t} = gl
  (a, GCons{sx, sy, c, t, acc})

# G glyphs as lines of 80 over a 1512 x 982 pt design at w x h px; columns
# [30, 40) scroll by off px (the dirty column scenario)
def sprites(+n: Nat, +i: U32, +w: U32, +h: U32, +off: U32, r: Array<Glyph> & Gs) -> Array<Glyph> & Gs:
  match n:
    case 0n:
      r
    case 1n+p:
      (a, acc) = r
      +line = (i / 80 : U32)
      +col = (i % 80 : U32)
      +sx = ((20 + col * 10) * w / 1512 : U32)
      +sy = ((15 + line * 22) * h / 982 + word(((col > 29) && (col < 40) : U32), off, 0) : U32)
      sprites(p, (i + 1 : U32), w, h, off,
        sprite.mk(Array.get(Glyph, a, (i % 96 : U32)), sx, sy, word(U32.is_even(line), 15790320, 11587839), acc))

def glyphs(+g: U32, +w: U32, +h: U32, +off: U32, a: Array<Glyph>) -> Array<Glyph> & Gs:
  sprites(U32.to_nat(g), 0, w, h, off, (a, GNil{}))
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

def word.dr(c: Bool, a: DR, b: DR) -> DR:
  match c:
    case True{}:
      a
    case False{}:
      b

def dirty.of(+sc: U32, +cols: U32, +rows: U32, +w: U32, +h: U32) -> DR:
  word.dr(U32.is_eq(sc, 1), dirty.card(cols, rows, w, h),
    word.dr(U32.is_eq(sc, 2), DR{(caret.x(w) - 3 : U32), (caret.y(h) - 3 : U32), (caret.x(w) + 6 : U32), (caret.y(h) + 36 : U32)},
      word.dr(U32.is_eq(sc, 3), DR{((20 + 30 * 10) * w / 1512 - 3 : U32), 0, ((20 + 39 * 10) * w / 1512 + 20 : U32), h},
        word.dr(U32.is_eq(sc, 4), DR{0, 0, w, h}, DR{0, 0, 0, 0}))))

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
def full.with(d: Array<Glyph> & Image, prev: Image) -> Array<Glyph> & Image & Image:
  (a, img) = d
  (a, img, prev)

def step.full(r: Array<Glyph> & Gs, qs: Qs, prev: Image, +big: Bool) -> IO(Array<Glyph> & Image & Image):
  do IO<Array<Glyph> & Image & Image>:
    c : Array<Glyph> & Cells <- IO.pure(Array<Glyph> & Cells, full.cells(r, qs, big))
    d : Array<Glyph> & Image & Cells <- IO.pure(Array<Glyph> & Image & Cells, full.show(c, big))
    IO.pure(Array<Glyph> & Image & Image, full.with(full.split(d), prev))

def inc.k(r: Array<Glyph> & Gs, qs: Qs, prev: Image, +d: DR, +big: Bool) -> Array<Glyph> & Image & Image:
  (a, gs) = r
  (a, inc.go(d, prev, qs, gs, big), Pix{0})

def step(full: Bool, r: Array<Glyph> & Gs, qs: Qs, prev: Image, +d: DR, +big: Bool) -> IO(Array<Glyph> & Image & Image):
  match full:
    case True{}:
      step.full(r, qs, prev, big)
    case False{}:
      IO.pure(Array<Glyph> & Image & Image, inc.k(r, qs, prev, d, big))

def wsplit(shown: Window & Image & List<Event>, a: Array<Glyph>, old: Image) -> Array<Glyph> & Image & Image & Window:
  (win, img, events) = shown
  (a, img, old, win)

def show.k(s: Array<Glyph> & Image & Image, win: Window) -> IO(Array<Glyph> & Image & Image & Window):
  (a, img, old) = s
  do IO<Array<Glyph> & Image & Image & Window>:
    shown : Window & Image & List<Event> <- Window.frame(win, img)
    Unit <- IO.sleep(0)
    IO.pure(Array<Glyph> & Image & Image & Window, wsplit(shown, a, old))

def wsplit2(s: Array<Glyph> & Image & Image & Window) -> (Array<Glyph> & Image & Image) & Window:
  (a, img, old, win) = s
  ((a, img, old), win)

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

def Array.sink(-T: Type, a: Array<T>) -> Unit:
  Unit{}

def finish(a: Array<Glyph>) -> IO(Unit):
  do IO<Unit>:
    +rss : U32 <- Rss.kb()
    IO.print("done rss_kb " ++ U32.show(rss))
    IO.pure(Unit, Array.sink(Glyph, a))

def dend(a: Array<Glyph>, prev: Image, win: Window) -> IO(Unit):
  do IO<Unit>:
    Unit <- Window.close(win)
    IO.pure(Unit, Image.drop!(prev))
    finish(a)

def hd.of(+mode: U32, +sc: U32, +cols: U32, +rows: U32, +w: U32, +h: U32, +i: U32, +d: DR) -> String:
  "v " ++ U32.show(mode) ++ " sc " ++ U32.show(sc) ++ " n " ++ U32.show((cols * rows : U32)) ++ " w " ++ U32.show(w) ++ " h " ++ U32.show(h)
    ++ " f " ++ U32.show(i) ++ " dirty_px " ++ U32.show(dr.area(d))

def wloop.k(w2: (Array<Glyph> & Image & Image) & Window, +hd: String, +t0: U32, +t1: U32, +t2: U32, +t3: U32,
  k: Array<Glyph> -> Image -> Window -> IO(Unit)) -> IO(Unit):
  (s2, win) = w2
  do IO<Unit>:
    r2 : Array<Glyph> & Image <- IO.pure(Array<Glyph> & Image, drop.old(s2))
    +t4 : U32 <- Clock.us()
    dsay(r2, hd, t0, t1, t2, t3, t4, a2 => img2 => k(a2, img2, win))

def dloop(+n: Nat, +cfg: Cfg, +sc: U32, a: Array<Glyph>, prev: Image, win: Window) -> IO(Unit):
  match n:
    case 0n:
      dend(a, prev, win)
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
        sw : Array<Glyph> & Image & Image & Window <- show.k(s, win)
        +t3 : U32 <- Clock.us()
        w2 : (Array<Glyph> & Image & Image) & Window <- IO.pure((Array<Glyph> & Image & Image) & Window, wsplit2(sw))
        wloop.k(w2, hd.of(mode, sc, cols, rows, w, h, i, d), t0, t1, t2, t3, a2 => img2 => win2 => dloop(p, cfg, sc, a2, img2, win2))

def first.k(r: Array<Glyph> & Image & Image) -> Array<Glyph> & Image:
  (a, img, old) = r
  (a, img)

def cfg.frames(c: Cfg) -> Nat:
  Cfg{cols, rows, w, h, frames, pace, m, blit, g, check} = c
  U32.to_nat(frames)

def drun2(r: Array<Glyph> & Image, +cfg: Cfg, +sc: U32, win: Window) -> IO(Unit):
  (a, img) = r
  dloop(cfg.frames(cfg), cfg, sc, a, img, win)

def drun(+cfg: Cfg, +sc: U32) -> IO(Unit):
  Cfg{+cols, +rows, +w, +h, frames, pace, mode, blit, +g, check} = cfg
  do IO<Unit>:
    a : Array<Glyph> <- IO.pure(Array<Glyph>, atlas())
    r : Array<Glyph> & Gs <- IO.pure(Array<Glyph> & Gs, glyphs(g, w, h, 0, a))
    win : Window <- IO.try(Window, Window.open("dirty", (w / 2 : U32), (h / 2 : U32)))
    f : Array<Glyph> & Image & Image <- step.full(r, scene.of(0, 0, cols, rows, w, h), Pix{0}, isbig(w, h))
    drun2(first.k(f), cfg, sc, win)

def main() -> IO(Unit):
  do IO<Unit>:
    +cfg : Cfg <- config()
    +sc : U32 <- env("UI_SCEN", 1)
    drun(cfg, sc)
