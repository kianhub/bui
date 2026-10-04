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
type Glyph is Data:
  Glyph{r0: U32, r1: U32, r2: U32, r3: U32, r4: U32, r5: U32, r6: U32, r7: U32,
    r8: U32, r9: U32, r10: U32, r11: U32, r12: U32, r13: U32, r14: U32, r15: U32}

type Gs is Data:
  GNil{}
  GCons{sx: U32, sy: U32, c: U32, r0: U32, r1: U32, r2: U32, r3: U32, r4: U32, r5: U32, r6: U32, r7: U32,
    r8: U32, r9: U32, r10: U32, r11: U32, r12: U32, r13: U32, r14: U32, r15: U32, next: Gs}

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

def Gs.sink(gs: Gs) -> Unit:
  match gs:
    case GNil{}:
      Unit{}
    case GCons{_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, next}:
      Gs.sink(next)

def Gs.empty(gs: Gs) -> Bool:
  match gs:
    case GNil{}:
      True{}
    case GCons{_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _}:
      False{}

# Shading, front to back: glyphs first, then quads; t is the light left.
# ----------------------------------------------------------------------

# the row word of a glyph for dy in 0..15
def row.sel(+dy: U32, +r0: U32, +r1: U32, +r2: U32, +r3: U32, +r4: U32, +r5: U32, +r6: U32, +r7: U32,
  +r8: U32, +r9: U32, +r10: U32, +r11: U32, +r12: U32, +r13: U32, +r14: U32, +r15: U32) -> U32:
  word((dy < 8 : U32),
    word((dy < 4 : U32), word((dy < 2 : U32), word((dy < 1 : U32), r0, r1), word((dy < 3 : U32), r2, r3)),
      word((dy < 6 : U32), word((dy < 5 : U32), r4, r5), word((dy < 7 : U32), r6, r7))),
    word((dy < 12 : U32), word((dy < 10 : U32), word((dy < 9 : U32), r8, r9), word((dy < 11 : U32), r10, r11)),
      word((dy < 14 : U32), word((dy < 13 : U32), r12, r13), word((dy < 15 : U32), r14, r15))))

# the 4-bit alpha of texel dx in 0..7 of a row word
def nib(+dx: U32, +row: U32) -> U32:
  U32.and(word((dx < 4 : U32),
    word((dx < 2 : U32), word((dx < 1 : U32), row, (row >> 4n : U32)), word((dx < 3 : U32), (row >> 8n : U32), (row >> 12n : U32))),
    word((dx < 6 : U32), word((dx < 5 : U32), (row >> 16n : U32), (row >> 20n : U32)), word((dx < 7 : U32), (row >> 24n : U32), (row >> 28n : U32)))), 15)

def alpha(inside: Bool, +dx: U32, +dy: U32, +r0: U32, +r1: U32, +r2: U32, +r3: U32, +r4: U32, +r5: U32, +r6: U32, +r7: U32,
  +r8: U32, +r9: U32, +r10: U32, +r11: U32, +r12: U32, +r13: U32, +r14: U32, +r15: U32) -> F32:
  match inside:
    case False{}:
      0.0
    case True{}:
      (U32.to_f32(nib(dx, row.sel(dy, r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15))) * 0.0666667 : F32)

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

def px.sp(gs: Gs, +x: U32, +y: U32, +px: F32, +py: F32, +ts: Qs, +cr: F32, +cg: F32, +cb: F32, +t: F32) -> U32:
  match gs:
    case GNil{}:
      px.q(ts, px, py, cr, cg, cb, t)
    case GCons{+sx, +sy, +c, +r0, +r1, +r2, +r3, +r4, +r5, +r6, +r7, +r8, +r9, +r10, +r11, +r12, +r13, +r14, +r15, next}:
      +dx = (x - sx : U32)
      +dy = (y - sy : U32)
      +al = alpha(((dx < 8) && (dy < 16) : U32), dx, dy, r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15)
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

def keepg(on: Bool, +sx: U32, +sy: U32, +c: U32, +r0: U32, +r1: U32, +r2: U32, +r3: U32, +r4: U32, +r5: U32, +r6: U32, +r7: U32,
  +r8: U32, +r9: U32, +r10: U32, +r11: U32, +r12: U32, +r13: U32, +r14: U32, +r15: U32, acc: Gs) -> Gs:
  match on:
    case True{}:
      GCons{sx, sy, c, r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15, acc}
    case False{}:
      acc

def cullg(gs: Gs, +x: U32, +y: U32, +x1: U32, +y1: U32, acc: Gs) -> Gs:
  match gs:
    case GNil{}:
      acc
    case GCons{+sx, +sy, +c, +r0, +r1, +r2, +r3, +r4, +r5, +r6, +r7, +r8, +r9, +r10, +r11, +r12, +r13, +r14, +r15, next}:
      cullg(next, x, y, x1, y1,
        keepg(((sx < x1) && (x < (sx + 8 : U32)) && (sy < y1) && (y < (sy + 16 : U32)) : U32),
          sx, sy, c, r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15, acc))

def revg(gs: Gs, acc: Gs) -> Gs:
  match gs:
    case GNil{}:
      acc
    case GCons{+sx, +sy, +c, +r0, +r1, +r2, +r3, +r4, +r5, +r6, +r7, +r8, +r9, +r10, +r11, +r12, +r13, +r14, +r15, next}:
      revg(next, GCons{sx, sy, c, r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15, acc})

def boxg(+gs: Gs, +x: U32, +y: U32, +s: U32) -> Gs:
  revg(cullg(gs, x, y, (x + s : U32), (y + s : U32), GNil{}), GNil{})

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

def cards(+n: Nat, +i: U32, +cols: U32, +cw: F32, +ch: F32, +ft: F32, acc: Qs) -> Qs:
  match n:
    case 0n:
      acc
    case 1n+p:
      +col = (i % cols : U32)
      +row = (i / cols : U32)
      +x0 = (U32.to_f32(col) * cw + 10.0 + ft : F32)
      +y0 = (U32.to_f32(row) * ch + 10.0 : F32)
      cards(p, (i + 1 : U32), cols, cw, ch, ft,
        QCons{x0, y0, (x0 + cw - 4.0 : F32), (y0 + ch - 4.0 : F32), 4.0, 1.0,
          U32.or(U32.and((i * 2654435761 : U32), 16777215), 4210752), 10526880, acc})

# top-first: the cards, then the panel at the tail (bottom-most)
def scene(+cols: U32, +rows: U32, +w: U32, +h: U32, +ft: F32) -> Qs:
  +fw = U32.to_f32(w)
  +fh = U32.to_f32(h)
  cards(U32.to_nat((cols * rows : U32)), 0, cols,
    ((fw - 16.0) / U32.to_f32(cols) : F32), ((fh - 16.0) / U32.to_f32(rows) : F32), ft,
    QCons{8.0, 8.0, (fw - 8.0 : F32), (fh - 8.0 : F32), 12.0, 2.0, 2763059, 4473935, QNil{}})

# the atlas: 96 glyphs; texel alpha from a hash (about 43% solid, 16% partial)
def texel(+g: U32, +dy: U32, +dx: U32) -> U32:
  +v = U32.shrn(((g + 1) * 2654435761 + dy * 1013904223 + dx * 3932081 : U32), 24n)
  U32.shrn(word((v < 110 : U32), 255, word((v < 150 : U32), ((v - 110) * 6 : U32), 0)), 4n)

def row.mk(+g: U32, +dy: U32) -> U32:
  (texel(g, dy, 0) .|. texel(g, dy, 1) << 4n .|. texel(g, dy, 2) << 8n .|. texel(g, dy, 3) << 12n
    .|. texel(g, dy, 4) << 16n .|. texel(g, dy, 5) << 20n .|. texel(g, dy, 6) << 24n .|. texel(g, dy, 7) << 28n : U32)

def glyph.mk(+g: U32) -> Glyph:
  Glyph{row.mk(g, 0), row.mk(g, 1), row.mk(g, 2), row.mk(g, 3), row.mk(g, 4), row.mk(g, 5), row.mk(g, 6), row.mk(g, 7),
    row.mk(g, 8), row.mk(g, 9), row.mk(g, 10), row.mk(g, 11), row.mk(g, 12), row.mk(g, 13), row.mk(g, 14), row.mk(g, 15)}

def atlas.fill(n: Nat, a: Array<Glyph>, +i: U32) -> Array<Glyph>:
  match n:
    case 0n:
      a
    case 1n+p:
      atlas.fill(p, Array.set(Glyph, a, i, glyph.mk(i)), (i + 1 : U32))

def atlas() -> Array<Glyph>:
  atlas.fill(96n, [{Glyph{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0} : Glyph} : Glyph^7n], 0)

# a sprite entry from its atlas glyph
def sprite.mk(r: Array<Glyph> & Glyph, +sx: U32, +sy: U32, +c: U32, acc: Gs) -> Array<Glyph> & Gs:
  (a, gl) = r
  Glyph{r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15} = gl
  (a, GCons{sx, sy, c, r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15, acc})

# G glyphs as lines of 80, placed over a 1920x1200 design scaled to w x h
def sprites(+n: Nat, +i: U32, +w: U32, +h: U32, r: Array<Glyph> & Gs) -> Array<Glyph> & Gs:
  match n:
    case 0n:
      r
    case 1n+p:
      (a, acc) = r
      +line = (i / 80 : U32)
      +col = (i % 80 : U32)
      +sx = ((40 + col * 10) * w / 1920 : U32)
      +sy = ((30 + line * 44) * h / 1200 : U32)
      sprites(p, (i + 1 : U32), w, h,
        sprite.mk(Array.get(Glyph, a, (i % 96 : U32)), sx, sy, word(U32.is_even(line), 15790320, 11587839), acc))

def glyphs(+g: U32, +w: U32, +h: U32, a: Array<Glyph>) -> Array<Glyph> & Gs:
  sprites(U32.to_nat(g), 0, w, h, (a, GNil{}))

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

# mode 0 after the bang: (atlas, image, t1)
def cull.fin(r: Array<Glyph> & Gs, qs: Qs, +big: Bool) -> Array<Glyph> & Image:
  (a, gs) = r
  (a, frame.show(qs, gs, big))

def with.t(r: Array<Glyph> & Image, +t1: U32) -> Array<Glyph> & Image & U32:
  (a, img) = r
  (a, img, t1)

# mode 1
def bin.cells(r: Array<Glyph> & Gs, qs: Qs, +big: Bool) -> Array<Glyph> & Cells:
  (a, gs) = r
  (a, cbuild(qs, gs, big))

def bin.show(r: Array<Glyph> & Cells, +big: Bool) -> Array<Glyph> & Image & Cells:
  (a, cells) = r
  (a, cells.show(cells, big))

def bin.fin(a: Array<Glyph>, img: Image, +t1: U32, u: Unit) -> Array<Glyph> & Image & U32:
  match u:
    case Unit{}:
      (a, img, t1)

def bin.split(d: Array<Glyph> & Image & Cells, +t1: U32) -> Array<Glyph> & Image & U32:
  (a, img, used) = d
  bin.fin(a, img, t1, cells.free(used))

# the bang sits right after a Clock.us step, so it is the root of that step
def draw.cull(+cols: U32, +rows: U32, +w: U32, +h: U32, +g: U32, +ft: F32, a: Array<Glyph>, +big: Bool) -> IO(Array<Glyph> & Image & U32):
  do IO<Array<Glyph> & Image & U32>:
    qs : Qs <- IO.pure(Qs, scene(cols, rows, w, h, ft))
    r : Array<Glyph> & Gs <- IO.pure(Array<Glyph> & Gs, glyphs(g, w, h, a))
    +t1 : U32 <- Clock.us()
    d : Array<Glyph> & Image <- IO.pure(Array<Glyph> & Image, cull.fin(r, qs, big))
    IO.pure(Array<Glyph> & Image & U32, with.t(d, t1))

def draw.bin(+cols: U32, +rows: U32, +w: U32, +h: U32, +g: U32, +ft: F32, a: Array<Glyph>, +big: Bool) -> IO(Array<Glyph> & Image & U32):
  do IO<Array<Glyph> & Image & U32>:
    qs : Qs <- IO.pure(Qs, scene(cols, rows, w, h, ft))
    r : Array<Glyph> & Gs <- IO.pure(Array<Glyph> & Gs, glyphs(g, w, h, a))
    c : Array<Glyph> & Cells <- IO.pure(Array<Glyph> & Cells, bin.cells(r, qs, big))
    +t1 : U32 <- Clock.us()
    d : Array<Glyph> & Image & Cells <- IO.pure(Array<Glyph> & Image & Cells, bin.show(c, big))
    IO.pure(Array<Glyph> & Image & U32, bin.split(d, t1))

def draw(bin: Bool, +cols: U32, +rows: U32, +w: U32, +h: U32, +g: U32, +ft: F32, a: Array<Glyph>, +big: Bool) -> IO(Array<Glyph> & Image & U32):
  match bin:
    case False{}:
      draw.cull(cols, rows, w, h, g, ft, a, big)
    case True{}:
      draw.bin(cols, rows, w, h, g, ft, a, big)

def present.blit(s: Array<Glyph> & Image & U32, +w: U32, +h: U32, +k: U32) -> IO(Array<Glyph> & Image & U32):
  (a, img, t1) = s
  do IO<Array<Glyph> & Image & U32>:
    shown : Image <- Blit.run(img, w, h, k)
    IO.pure(Array<Glyph> & Image & U32, (a, shown, t1))

def present(blit: Bool, s: Array<Glyph> & Image & U32, +w: U32, +h: U32, +k: U32) -> IO(Array<Glyph> & Image & U32):
  match blit:
    case False{}:
      IO.pure(Array<Glyph> & Image & U32, s)
    case True{}:
      present.blit(s, w, h, k)

def drop.fin(u: Unit, a: Array<Glyph>, +t1: U32) -> Array<Glyph> & U32:
  match u:
    case Unit{}:
      (a, t1)

def drop.go(s: Array<Glyph> & Image & U32) -> Array<Glyph> & U32:
  (a, img, t1) = s
  drop.fin(Image.drop!(img), a, t1)

def pace.go(on: Bool, +ms: U32) -> IO(Unit):
  match on:
    case False{}:
      IO.pure(Unit, Unit{})
    case True{}:
      IO.sleep(ms)

def frame.ft(+i: U32) -> F32:
  (U32.to_f32(U32.and(i, 7)) * 0.5 : F32)

def loop.say(r: Array<Glyph> & U32, +hd: String, +t0: U32, +t2: U32, +t3: U32, +t4: U32, +pace: U32, k: Array<Glyph> -> IO(Array<Glyph>)) -> IO(Array<Glyph>):
  (a, +t1) = r
  do IO<Array<Glyph>>:
    +rss : U32 <- Rss.kb()
    IO.print(hd ++ " build_us " ++ U32.show((t1 - t0 : U32)) ++ " render_us " ++ U32.show((t2 - t1 : U32))
      ++ " present_us " ++ U32.show((t3 - t2 : U32)) ++ " drop_us " ++ U32.show((t4 - t3 : U32))
      ++ " frame_us " ++ U32.show((t4 - t0 : U32)) ++ " rss_kb " ++ U32.show(rss))
    Unit <- pace.go(U32.is_ne(pace, 0), pace)
    k(a)

def line.head(+mode: U32, +cols: U32, +rows: U32, +w: U32, +h: U32, +i: U32) -> String:
  "v " ++ U32.show(mode) ++ " n " ++ U32.show((cols * rows : U32)) ++ " w " ++ U32.show(w) ++ " h " ++ U32.show(h) ++ " f " ++ U32.show(i)

# Headless loop: build, bang, Blit (the present kernel), drop
def loop(+n: Nat, +cfg: Cfg, a: Array<Glyph>) -> IO(Array<Glyph>):
  match n:
    case 0n:
      IO.pure(Array<Glyph>, a)
    case 1n+p:
      Cfg{+cols, +rows, +w, +h, +frames, +pace, +mode, +blit, +g, check} = cfg
      +i = (frames - U32.from_nat(p) - 1 : U32)
      +big = isbig(w, h)
      do IO<Array<Glyph>>:
        +t0 : U32 <- Clock.us()
        d : Array<Glyph> & Image & U32 <- draw(U32.is_eq(mode, 1), cols, rows, w, h, g, frame.ft(i), a, big)
        +t2 : U32 <- Clock.us()
        s : Array<Glyph> & Image & U32 <- present(U32.is_eq(blit, 1), d, w, h, root.k(w, h))
        +t3 : U32 <- Clock.us()
        r : Array<Glyph> & U32 <- IO.pure(Array<Glyph> & U32, drop.go(s))
        +t4 : U32 <- Clock.us()
        loop.say(r, line.head(mode, cols, rows, w, h, i), t0, t2, t3, t4, pace, a2 => loop(p, cfg, a2))

# Check: one frame (ft of frame 7), its area sum and leaf count, the Blit
# texture's hash and four texel probes against the reference shading of
# the full lists (no culling, no collapse).
def probe.say(+ref: U32, +x: U32, +y: U32) -> IO(Unit):
  do IO<Unit>:
    +tex : U32 <- Blit.pick(x, y)
    IO.print("probe x " ++ U32.show(x) ++ " y " ++ U32.show(y) ++ " ref " ++ U32.show(ref) ++ " tex " ++ U32.show(tex)
      ++ " ok " ++ Bool.show(U32.is_eq(ref, tex)))

def probes.go(+qs: Qs, +gs: Gs, +w: U32, +h: U32) -> IO(Unit):
  # a card interior, a card border row, a glyph texel, the background corner
  +px1 = (w / 2 + 7 : U32)
  +py1 = (h / 2 + 9 : U32)
  +gx = ((40 * w / 1920) + 3 : U32)
  +gy = ((30 * h / 1200) + 5 : U32)
  do IO<Unit>:
    Unit <- probe.say(px(qs, gs, px1, py1), px1, py1)
    Unit <- probe.say(px(qs, gs, 10, (h / 2 : U32)), 10, (h / 2 : U32))
    Unit <- probe.say(px(qs, gs, gx, gy), gx, gy)
    probe.say(px(qs, gs, (w - 2 : U32), (h - 2 : U32)), (w - 2 : U32), (h - 2 : U32))

def probes(r: Array<Glyph> & Gs, +qs: Qs, +w: U32, +h: U32, k: Array<Glyph> -> IO(Array<Glyph>)) -> IO(Array<Glyph>):
  (a, gs) = r
  do IO<Array<Glyph>>:
    Unit <- probes.go(qs, gs, w, h)
    k(a)

def check.img2(a: Array<Glyph>, +img: Image, +cfg: Cfg, k: Array<Glyph> -> IO(Array<Glyph>)) -> IO(Array<Glyph>):
  Cfg{+cols, +rows, +w, +h, frames, pace, +mode, blit, +g, check} = cfg
  do IO<Array<Glyph>>:
    IO.print("check v " ++ U32.show(mode) ++ " n " ++ U32.show((cols * rows : U32)) ++ " w " ++ U32.show(w) ++ " h " ++ U32.show(h)
      ++ " isum " ++ U32.show(isum(img, U32.shln(1, U32.to_nat(root.k(w, h))), 0, 0, w, h)) ++ " leaves " ++ U32.show(leaves(img)))
    shown : Image <- Blit.run(img, w, h, root.k(w, h))
    +sum : U32 <- Blit.sum()
    IO.print("blit_sum " ++ U32.show(sum))
    Unit <- IO.pure(Unit, Image.drop!(shown))
    probes(glyphs(g, w, h, a), scene(cols, rows, w, h, frame.ft(7)), w, h, k)

def check.img(s: Array<Glyph> & Image & U32, +cfg: Cfg, k: Array<Glyph> -> IO(Array<Glyph>)) -> IO(Array<Glyph>):
  (a, img, t1) = s
  check.img2(a, img, cfg, k)

def check(+cfg: Cfg, a: Array<Glyph>, k: Array<Glyph> -> IO(Array<Glyph>)) -> IO(Array<Glyph>):
  Cfg{+cols, +rows, +w, +h, frames, pace, +mode, blit, +g, check} = cfg
  do IO<Array<Glyph>>:
    d : Array<Glyph> & Image & U32 <- draw(U32.is_eq(mode, 1), cols, rows, w, h, g, frame.ft(7), a, isbig(w, h))
    check.img(d, cfg, k)

def run.checked(on: Bool, +cfg: Cfg, a: Array<Glyph>, k: Array<Glyph> -> IO(Array<Glyph>)) -> IO(Array<Glyph>):
  match on:
    case False{}:
      k(a)
    case True{}:
      check(cfg, a, k)

def Array.sink(-T: Type, a: Array<T>) -> Unit:
  Unit{}

def finish(a: Array<Glyph>) -> IO(Unit):
  do IO<Unit>:
    +rss : U32 <- Rss.kb()
    IO.print("done rss_kb " ++ U32.show(rss))
    IO.pure(Unit, Array.sink(Glyph, a))
# Gap 4 drift: the cull-cpu12 loop of v/measure (scene, cull bang-in-place on
# the CPU pool with --gpu off, Blit present, drop) plus, every frame,
#  - about 2,000 chars of text built from String concatenation and U32.show
#    of the frame counter, turned into the frame's glyph sprites (so the text
#    is consumed by the renderer, as a UI's text runs are), and
#  - a 200-entry Map<&2, U32> of element state keyed by Strings built with
#    U32.show, rebuilt every frame from the previous frame's map (GPUI moves
#    element state from the rendered frame to the next one), old map dropped.
# Env: as ui_common, plus UI_CELLS (text cells per frame, default 118) and
# UI_KEYS (map entries, default 200).

# Text: cells of "e<k>=<hash> " joined by ++, U32.show temporaries throughout
def tcell(+k: U32, +f: U32) -> String:
  "e" ++ U32.show(k) ++ "=" ++ U32.show((f * 2654435761 + k * 40503 : U32)) ++ " "

def text.go(n: Nat, +k: U32, +f: U32) -> String:
  match n:
    case 0n:
      ""
    case 1n+p:
      tcell(k, f) ++ text.go(p, (k + 1 : U32), f)

def text(+cells: U32, +f: U32) -> String:
  text.go(U32.to_nat(cells), 0, f)

# text -> sprites, 80 columns, glyph = atlas[code % 96]
def tsprites(s: String, +i: U32, +w: U32, +h: U32, r: Array<Glyph> & Gs) -> Array<Glyph> & Gs & U32:
  match s:
    case SNil{}:
      (a, acc) = r
      (a, acc, i)
    case SCon{Chr{+c}, t}:
      (a, acc) = r
      +line = (i / 80 : U32)
      +col = (i % 80 : U32)
      +sx = ((40 + col * 10) * w / 1920 : U32)
      +sy = ((30 + line * 44) * h / 1200 : U32)
      tsprites(t, (i + 1 : U32), w, h,
        sprite.mk(Array.get(Glyph, a, (c % 96 : U32)), sx, sy, word(U32.is_even(line), 15790320, 11587839), acc))

# Element state: keys "element/<k>/state", value moved from the old map, +1
def ekey(+k: U32) -> String:
  "element/" ++ U32.show(k) ++ "/state"

type ES is Data:
  ES{old: Map<&2, U32>, acc: Map<&2, U32>, sum: U32}

def estate.step(r: Map<&2, U32> & U32, acc: Map<&2, U32>, +k: U32, +sum: U32) -> ES:
  (old, +v) = r
  ES{old, Map.set(&2, U32, acc, ekey(k), (v + 1 : U32)), (sum + v : U32)}

def estate.go(n: Nat, +k: U32, r: ES) -> ES:
  match n:
    case 0n:
      r
    case 1n+p:
      ES{old, acc, +sum} = r
      estate.go(p, (k + 1 : U32), estate.step(Map.get(U32, k, old, ekey(k)), acc, k, sum))

def estate.fin(r: ES) -> Map<&2, U32> & U32:
  ES{old, acc, sum} = r
  (acc, sum)

def estate(+keys: U32, old: Map<&2, U32>) -> Map<&2, U32> & U32:
  estate.fin(estate.go(U32.to_nat(keys), 0, ES{old, Map.new(&2, U32), 0}))

# #1307's shape at UI scale: a list of Type records wrapping a small Array,
# built every frame and dropped by automatic erasure (never matched).
type Blob is Type:
  Blob{size: U32, buffer: Array<U32>}

type Item is Type:
  Item{blob: Blob}

def runs.build(count: Nat, +f: U32, +d: Nat, acc: List<&1, Item>) -> List<&1, Item>:
  match count:
    case 0n:
      acc
    case 1n+rest:
      runs.build(rest, f, d, Item{Blob{f, Array.new(U32, d, f)}} <> acc)

def runs.auto(xs: List<&1, Item>, +n: U32) -> U32:
  n

# Frame
type Cfg4 is Data:
  Cfg4{cells: U32, keys: U32, runs: U32, rdepth: U32}

def draw4.fin(r: Array<Glyph> & Gs & U32, qs: Qs, +big: Bool) -> Array<Glyph> & Image & U32:
  (a, gs, nch) = r
  (a, frame.show(qs, gs, big), nch)

def draw4.t(d: Array<Glyph> & Image & U32, +t1: U32) -> Array<Glyph> & Image & U32 & U32:
  (a, img, nch) = d
  (a, img, nch, t1)

def draw4(+cols: U32, +rows: U32, +w: U32, +h: U32, +ft: F32, +cells: U32, +f: U32, a: Array<Glyph>, +big: Bool) -> IO(Array<Glyph> & Image & U32 & U32):
  do IO<Array<Glyph> & Image & U32 & U32>:
    qs : Qs <- IO.pure(Qs, scene(cols, rows, w, h, ft))
    r : Array<Glyph> & Gs & U32 <- IO.pure(Array<Glyph> & Gs & U32, tsprites(text(cells, f), 0, w, h, (a, GNil{})))
    +t1 : U32 <- Clock.us()
    d : Array<Glyph> & Image & U32 <- IO.pure(Array<Glyph> & Image & U32, draw4.fin(r, qs, big))
    IO.pure(Array<Glyph> & Image & U32 & U32, draw4.t(d, t1))

def present4(s: Array<Glyph> & Image & U32 & U32, +w: U32, +h: U32, +k: U32) -> IO(Array<Glyph> & Image & U32 & U32):
  (a, img, nch, t1) = s
  do IO<Array<Glyph> & Image & U32 & U32>:
    shown : Image <- Blit.run(img, w, h, k)
    IO.pure(Array<Glyph> & Image & U32 & U32, (a, shown, nch, t1))

def drop4.fin(u: Unit, a: Array<Glyph>, +nch: U32, +t1: U32) -> Array<Glyph> & U32 & U32:
  match u:
    case Unit{}:
      (a, nch, t1)

def drop4(s: Array<Glyph> & Image & U32 & U32) -> Array<Glyph> & U32 & U32:
  (a, img, nch, t1) = s
  drop4.fin(Image.drop!(img), a, nch, t1)

def say4.go(a: Array<Glyph>, +nch: U32, +t1: U32, m: Map<&2, U32>, +sum: U32, +hd: String, +t0: U32, +tm: U32, +t2: U32, +t3: U32, +t4: U32,
  k: Array<Glyph> -> Map<&2, U32> -> IO(Unit)) -> IO(Unit):
  do IO<Unit>:
    +rss : U32 <- Rss.kb()
    IO.print(hd ++ " map_us " ++ U32.show((tm - t0 : U32)) ++ " build_us " ++ U32.show((t1 - tm : U32)) ++ " render_us " ++ U32.show((t2 - t1 : U32))
      ++ " present_us " ++ U32.show((t3 - t2 : U32)) ++ " drop_us " ++ U32.show((t4 - t3 : U32))
      ++ " frame_us " ++ U32.show((t4 - t0 : U32)) ++ " rss_kb " ++ U32.show(rss) ++ " chars " ++ U32.show(nch) ++ " msum " ++ U32.show(sum))
    k(a, m)

def say4.m(a: Array<Glyph>, +nch: U32, +t1: U32, ms: Map<&2, U32> & U32, +hd: String, +t0: U32, +tm: U32, +t2: U32, +t3: U32, +t4: U32,
  k: Array<Glyph> -> Map<&2, U32> -> IO(Unit)) -> IO(Unit):
  (m, sum) = ms
  say4.go(a, nch, t1, m, sum, hd, t0, tm, t2, t3, t4, k)

def say4(r: Array<Glyph> & U32 & U32, ms: Map<&2, U32> & U32, +hd: String, +t0: U32, +tm: U32, +t2: U32, +t3: U32, +t4: U32,
  k: Array<Glyph> -> Map<&2, U32> -> IO(Unit)) -> IO(Unit):
  (a, nch, t1) = r
  say4.m(a, nch, t1, ms, hd, t0, tm, t2, t3, t4, k)

def finish4(a: Array<Glyph>, m: Map<&2, U32>) -> IO(Unit):
  do IO<Unit>:
    +rss : U32 <- Rss.kb()
    IO.print("done rss_kb " ++ U32.show(rss) ++ " map_size " ++ Nat.show(Map.size(&2, U32, m)))
    IO.pure(Unit, Array.sink(Glyph, a))

def loop4(+n: Nat, +cfg: Cfg, +c4: Cfg4, a: Array<Glyph>, m: Map<&2, U32>) -> IO(Unit):
  match n:
    case 0n:
      finish4(a, m)
    case 1n+p:
      Cfg{+cols, +rows, +w, +h, +frames, pace, mode, blit, g, check} = cfg
      Cfg4{+cells, +keys, +runs, +rdepth} = c4
      +i = (frames - U32.from_nat(p) - 1 : U32)
      +big = isbig(w, h)
      do IO<Unit>:
        +t0 : U32 <- Clock.us()
        +nb : U32 <- IO.pure(U32, runs.auto(runs.build(U32.to_nat(runs), i, U32.to_nat(rdepth), Nil{}), runs))
        +tr : U32 <- Clock.us()
        ms : Map<&2, U32> & U32 <- IO.pure(Map<&2, U32> & U32, estate(keys, m))
        +tm : U32 <- Clock.us()
        d : Array<Glyph> & Image & U32 & U32 <- draw4(cols, rows, w, h, frame.ft(i), cells, i, a, big)
        +t2 : U32 <- Clock.us()
        s : Array<Glyph> & Image & U32 & U32 <- present4(d, w, h, root.k(w, h))
        +t3 : U32 <- Clock.us()
        r : Array<Glyph> & U32 & U32 <- IO.pure(Array<Glyph> & U32 & U32, drop4(s))
        +t4 : U32 <- Clock.us()
        say4(r, ms, line.head(0, cols, rows, w, h, i) ++ " runs_us " ++ U32.show((tr - t0 : U32)), tr, tm, t2, t3, t4, a2 => m2 => loop4(p, cfg, c4, a2, m2))

def run4(+cfg: Cfg, +cells: U32, +keys: U32, +runs: U32, +rdepth: U32) -> IO(Unit):
  Cfg{cols, rows, w, h, +frames, pace, mode, blit, g, check} = cfg
  do IO<Unit>:
    a : Array<Glyph> <- IO.pure(Array<Glyph>, atlas())
    loop4(U32.to_nat(frames), cfg, Cfg4{cells, keys, runs, rdepth}, a, Map.new(&2, U32))

def main() -> IO(Unit):
  do IO<Unit>:
    +cfg : Cfg <- config()
    +cells : U32 <- env("UI_CELLS", 118)
    +keys : U32 <- env("UI_KEYS", 200)
    +runs : U32 <- env("UI_RUNS", 4096)
    +rdepth : U32 <- env("UI_RUNDEPTH", 0)
    run4(cfg, cells, keys, runs, rdepth)
