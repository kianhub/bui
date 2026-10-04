import Base

# A GPUI-like scene: one rounded panel plus a C x R grid of rounded
# "cards" (N = C*R quads), rasterised into the Image quadtree that
# Window.frame takes. The host builds the quad list each frame; one
# bang culls it hierarchically down a 4-way fork tree (2048 -> 16-px
# tiles, 7 levels) and each tile shades its pixels front-to-back over
# its own short list. Empty regions collapse to one Pix.

def Clock.us() -> IO(U32):
  import "./clock.c"
  import "./clock.js"

def Blit.run(image: Image) -> IO(Image):
  import "./blit.c"
  import "./blit.js"

def pick(c: Bool, a: F32, b: F32) -> F32:
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

type Qs is Data:
  QNil{}
  QCons{x0: F32, y0: F32, x1: F32, y1: F32, r: F32, c: U32, next: Qs}

# front-to-back over a top-first list: a = coverage * remaining
def px.go(ts: Qs, +px: F32, +py: F32, +cr: F32, +cg: F32, +cb: F32, +t: F32) -> U32:
  match ts:
    case QNil{}:
      pack((cr + t * 0.10 : F32), (cg + t * 0.11 : F32), (cb + t * 0.13 : F32))
    case QCons{+x0, +y0, +x1, +y1, +r, +c, next}:
      +a = (cov(rsdf(px, py, x0, y0, x1, y1, r)) * t : F32)
      px.go(next, px, py, (cr + a * chan(c, 16n) : F32), (cg + a * chan(c, 8n) : F32),
        (cb + a * chan(c, 0n) : F32), (t - a : F32))

def px(+ts: Qs, +x: U32, +y: U32) -> U32:
  px.go(ts, (U32.to_f32(x) + 0.5 : F32), (U32.to_f32(y) + 0.5 : F32), 0.0, 0.0, 0.0, 1.0)

def blk.mk(same: Bool, +c0: U32, +c1: U32, +c2: U32, +c3: U32) -> Image:
  match same:
    case True{}:
      Pix{c0}
    case False{}:
      Qua{Pix{c0}, Pix{c1}, Pix{c2}, Pix{c3}}

def blk(+ts: Qs, +x: U32, +y: U32) -> Image:
  +x1 = (x + 1 : U32)
  +y1 = (y + 1 : U32)
  +c0 = px(ts, x, y)
  +c1 = px(ts, x1, y)
  +c2 = px(ts, x, y1)
  +c3 = px(ts, x1, y1)
  blk.mk((U32.is_eq(c0, c1) && U32.is_eq(c1, c2) && U32.is_eq(c2, c3)), c0, c1, c2, c3)

def t4(+ts: Qs, +x: U32, +y: U32) -> Image:
  +x1 = (x + 2 : U32)
  +y1 = (y + 2 : U32)
  Qua{blk(ts, x, y), blk(ts, x1, y), blk(ts, x, y1), blk(ts, x1, y1)}

def t8(+ts: Qs, +x: U32, +y: U32) -> Image:
  +x1 = (x + 4 : U32)
  +y1 = (y + 4 : U32)
  Qua{t4(ts, x, y), t4(ts, x1, y), t4(ts, x, y1), t4(ts, x1, y1)}

def t16(+ts: Qs, +x: U32, +y: U32) -> Image:
  +x1 = (x + 8 : U32)
  +y1 = (y + 8 : U32)
  Qua{t8(ts, x, y), t8(ts, x1, y), t8(ts, x, y1), t8(ts, x1, y1)}

# the tile's list freed after its pixels read it
def tile.fin(img: Image, ts: Qs) -> Image:
  match ts:
    case QNil{}:
      img
    case QCons{_, _, _, _, _, _, next}:
      tile.fin(img, next)

def keep(on: Bool, +x0: F32, +y0: F32, +x1: F32, +y1: F32, +r: F32, +c: U32, acc: Qs) -> Qs:
  match on:
    case True{}:
      QCons{x0, y0, x1, y1, r, c, acc}
    case False{}:
      acc

# the entries meeting the box (reverses the order)
def cull(qs: Qs, +bx0: F32, +by0: F32, +bx1: F32, +by1: F32, acc: Qs) -> Qs:
  match qs:
    case QNil{}:
      acc
    case QCons{+x0, +y0, +x1, +y1, +r, +c, next}:
      cull(next, bx0, by0, bx1, by1,
        keep(((x0 < bx1) && (x1 > bx0) && (y0 < by1) && (y1 > by0) : F32), x0, y0, x1, y1, r, c, acc))

def Qs.empty(qs: Qs) -> Bool:
  match qs:
    case QNil{}:
      True{}
    case QCons{_, _, _, _, _, _, _}:
      False{}

def box(+qs: Qs, +x: U32, +y: U32, +s: U32) -> Qs:
  cull(qs, (U32.to_f32(x) - 1.0 : F32), (U32.to_f32(y) - 1.0 : F32),
    (U32.to_f32((x + s : U32)) + 1.0 : F32), (U32.to_f32((y + s : U32)) + 1.0 : F32), QNil{})

def node.go(+k: Nat, empty: Bool, +qs: Qs, +x: U32, +y: U32) -> Image:
  match k empty:
    case _ True{}:
      Pix{1711393}
    case 0n False{}:
      tile.fin(t16(qs, x, y), qs)
    case 1n+e False{}:
      +s = U32.shln(16, e)
      +x1 = (x + s : U32)
      +y1 = (y + s : U32)
      +la = box(qs, x, y, s)
      +lb = box(qs, x1, y, s)
      +lc = box(qs, x, y1, s)
      +ld = box(qs, x1, y1, s)
      _ = qs
      a b c d = node.go(e, Qs.empty(la), la, x, y) node.go(e, Qs.empty(lb), lb, x1, y)
        node.go(e, Qs.empty(lc), lc, x, y1) node.go(e, Qs.empty(ld), ld, x1, y1)
      Qua{a, b, c, d}

def frame(+qs: Qs) -> Image:
  node.go(7n, Qs.empty(qs), qs, 0, 0)

# host: the C x R cards, then the panel at the head (bottom-most)
def cards(+n: Nat, +i: U32, +cols: U32, +cw: F32, +ch: F32, +ft: F32, acc: Qs) -> Qs:
  match n:
    case 0n:
      acc
    case 1n+p:
      +col = (i % cols : U32)
      +row = (i / cols : U32)
      +x0 = (U32.to_f32(col) * cw + 2.0 + ft : F32)
      +y0 = (U32.to_f32(row) * ch + 2.0 : F32)
      cards(p, (i + 1 : U32), cols, cw, ch, ft,
        QCons{x0, y0, (x0 + cw - 4.0 : F32), (y0 + ch - 4.0 : F32), 4.0,
          U32.and((i * 2654435761 : U32), 16777215), acc})

def scene(+cols: U32, +rows: U32, +ft: F32) -> Qs:
  QCons{8.0, 8.0, 1912.0, 1072.0, 12.0, 2763061,
    cards(U32.to_nat((cols * rows : U32)), 0, cols,
      (1920.0 / U32.to_f32(cols) : F32), (1080.0 / U32.to_f32(rows) : F32), ft, QNil{})}

def span(+a: U32, +s: U32, +lim: U32) -> U32:
  U32.min(s, (lim - U32.min(a, lim) : U32))

def isum(img: Image, +s: U32, +x: U32, +y: U32) -> U32:
  match img:
    case Pix{c}:
      (c * span(x, s, 1920) * span(y, s, 1080) : U32)
    case Qua{a, b, c, d}:
      +h = U32.shr(s)
      +x1 = (x + h : U32)
      +y1 = (y + h : U32)
      (isum(a, h, x, y) + isum(b, h, x1, y) + isum(c, h, x, y1) + isum(d, h, x1, y1) : U32)

def leaves(img: Image) -> U32:
  match img:
    case Pix{c}:
      1
    case Qua{a, b, c, d}:
      (leaves(a) + leaves(b) + leaves(c) + leaves(d) : U32)

def loop(+cols: U32, +rows: U32, +n: Nat) -> IO(Unit):
  match n:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      do IO<Unit>:
        +t0 : U32 <- Clock.us()
        qs : Qs <- IO.pure(Qs, scene(cols, rows, F32.from_nat(p)))
        +t1 : U32 <- Clock.us()
        img : Image <- IO.pure(Image, frame!(qs))
        +t2 : U32 <- Clock.us()
        shown : Image <- Blit.run(img)
        +t3 : U32 <- Clock.us()
        u : Unit <- IO.pure(Unit, Image.drop!(shown))
        +t4 : U32 <- Clock.us()
        IO.print("n " ++ U32.show((cols * rows : U32)) ++ " build_us " ++ U32.show((t1 - t0 : U32)) ++ " render_us " ++ U32.show((t2 - t1 : U32)) ++ " blit_us " ++ U32.show((t3 - t2 : U32)) ++ " drop_us " ++ U32.show((t4 - t3 : U32)) ++ " frame_us " ++ U32.show((t4 - t0 : U32)))
        loop(cols, rows, p)

def check(+cols: U32, +rows: U32) -> IO(Unit):
  do IO<Unit>:
    qs : Qs <- IO.pure(Qs, scene(cols, rows, 7.0))
    +img : Image <- IO.pure(Image, frame!(qs))
    IO.print("n " ++ U32.show((cols * rows : U32)) ++ " isum " ++ U32.show(isum(img, 2048, 0, 0)) ++ " leaves " ++ U32.show(leaves(img)))

def main() -> IO(Unit):
  do IO<Unit>:
    check(16, 16)
    check(32, 32)
    check(64, 64)
    loop(16, 16, 40n)
    loop(32, 32, 40n)
    loop(64, 64, 40n)
