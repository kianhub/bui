# 2x glyphs: 16 x 32 texels of 8-bit coverage. A glyph is a balanced tree of
# its 32 rows (GT, depth 5), each row 4 words of 4 texels; the atlas holds 96
# of them and a sprite shares its glyph's tree (a refcounted reference, as a
# GPU sprite references an atlas tile) instead of copying texels.
type GT is Data:
  GL{a: U32, b: U32, c: U32, d: U32}
  GN{lo: GT, hi: GT}

type Glyph is Data:
  Glyph{t: GT}

type Gs is Data:
  GNil{}
  GCons{sx: U32, sy: U32, c: U32, g: GT, next: Gs}

def Gs.sink(gs: Gs) -> Unit:
  match gs:
    case GNil{}:
      Unit{}
    case GCons{_, _, _, _, next}:
      Gs.sink(next)

def Gs.empty(gs: Gs) -> Bool:
  match gs:
    case GNil{}:
      True{}
    case GCons{_, _, _, _, _}:
      False{}

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

# texel (0..255) at row dy, column dx of a glyph tree of depth lvl
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
