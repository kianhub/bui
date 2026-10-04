import Base

# The same 4-quad frame, built as the Image quadtree Window.frame takes.
# A 2048 root over 1920x1080; 7 levels of 4-way fork to 16-px tiles
# (4^7 = 16384 = the lane cube); a tile is straight-line Qua nesting
# down to 2x2 blocks (one Pix when the 4 pixels agree). fl=True also
# collapses any region whose pixels provably share one colour (SDF
# Lipschitz bound) into one Pix before forking: the UI-typical case.

def Clock.us() -> IO(U32):
  import "./clock.c"
  import "./clock.js"

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

def d1(+px: F32, +py: F32, +ft: F32) -> F32:
  sdf(px, py, (480.0 + ft : F32), 300.0, 400.0, 220.0, 16.0)

def d2(+px: F32, +py: F32, +ft: F32) -> F32:
  sdf(px, py, 1300.0, (500.0 + ft : F32), 360.0, 300.0, 24.0)

def d3(+px: F32, +py: F32, +ft: F32) -> F32:
  sdf(px, py, 960.0, 900.0, (800.0 + ft : F32), 80.0, 40.0)

def d4(+px: F32, +py: F32, +ft: F32) -> F32:
  sdf(px, py, (700.0 - ft : F32), 640.0, 120.0, 120.0, 60.0)

def cov(+d: F32) -> F32:
  sat((0.5 - d : F32))

def over(+dst: F32, +src: F32, +a: F32) -> F32:
  (dst + (src - dst) * a : F32)

def pack(+r: F32, +g: F32, +b: F32) -> U32:
  (F32.to_u32((255.0 * sat(r) : F32)) << 16n
    .|. F32.to_u32((255.0 * sat(g) : F32)) << 8n
    .|. F32.to_u32((255.0 * sat(b) : F32)) : U32)

def shade(+x: U32, +y: U32, +ft: F32) -> U32:
  +px = (U32.to_f32(x) + 0.5 : F32)
  +py = (U32.to_f32(y) + 0.5 : F32)
  +a1 = cov(d1(px, py, ft))
  +a2 = cov(d2(px, py, ft))
  +a3 = cov(d3(px, py, ft))
  +a4 = cov(d4(px, py, ft))
  +r = over(over(over(over(0.10, 0.90, a1), 0.20, a2), 0.95, a3), 0.40, a4)
  +g = over(over(over(over(0.11, 0.90, a1), 0.50, a2), 0.60, a3), 0.80, a4)
  +b = over(over(over(over(0.13, 0.92, a1), 0.90, a2), 0.20, a3), 0.40, a4)
  pack(r, g, b)

def blk.mk(same: Bool, +c0: U32, +c1: U32, +c2: U32, +c3: U32) -> Image:
  match same:
    case True{}:
      Pix{c0}
    case False{}:
      Qua{Pix{c0}, Pix{c1}, Pix{c2}, Pix{c3}}

def blk(+x: U32, +y: U32, +ft: F32) -> Image:
  +x1 = (x + 1 : U32)
  +y1 = (y + 1 : U32)
  +c0 = shade(x, y, ft)
  +c1 = shade(x1, y, ft)
  +c2 = shade(x, y1, ft)
  +c3 = shade(x1, y1, ft)
  blk.mk((U32.is_eq(c0, c1) && U32.is_eq(c1, c2) && U32.is_eq(c2, c3)), c0, c1, c2, c3)

def t4(+x: U32, +y: U32, +ft: F32) -> Image:
  +x1 = (x + 2 : U32)
  +y1 = (y + 2 : U32)
  Qua{blk(x, y, ft), blk(x1, y, ft), blk(x, y1, ft), blk(x1, y1, ft)}

def t8(+x: U32, +y: U32, +ft: F32) -> Image:
  +x1 = (x + 4 : U32)
  +y1 = (y + 4 : U32)
  Qua{t4(x, y, ft), t4(x1, y, ft), t4(x, y1, ft), t4(x1, y1, ft)}

def t16(+x: U32, +y: U32, +ft: F32) -> Image:
  +x1 = (x + 8 : U32)
  +y1 = (y + 8 : U32)
  Qua{t8(x, y, ft), t8(x1, y, ft), t8(x, y1, ft), t8(x1, y1, ft)}

def far(+d: F32, +m: F32) -> Bool:
  (F32.abs(d) >= m : F32)

# Every pixel centre of the s x s region at (x, y) has one colour when
# each quad's SDF at the region centre is farther than the half
# diagonal plus the half-pixel AA band.
def isflat(fl: Bool, +s: U32, +x: U32, +y: U32, +ft: F32) -> Bool:
  match fl:
    case False{}:
      False{}
    case True{}:
      +h = (U32.to_f32(s) * 0.5 : F32)
      +cx = (U32.to_f32(x) + h : F32)
      +cy = (U32.to_f32(y) + h : F32)
      +m = (h * 1.4143 + 0.5 : F32)
      far(d1(cx, cy, ft), m) && far(d2(cx, cy, ft), m) && far(d3(cx, cy, ft), m)
        && far(d4(cx, cy, ft), m)

def node(+k: Nat, on: Bool, flat: Bool, +x: U32, +y: U32, +ft: F32, +fl: Bool) -> Image:
  match k on flat:
    case _ False{} _:
      Pix{0}
    case _ True{} True{}:
      Pix{shade(x, y, ft)}
    case 0n True{} False{}:
      t16(x, y, ft)
    case 1n+e True{} False{}:
      +s = U32.shln(16, e)
      +x1 = (x + s : U32)
      +y1 = (y + s : U32)
      a b c d = node(e, True{}, isflat(fl, s, x, y, ft), x, y, ft, fl)
        node(e, (x1 < 1920 : U32), isflat(fl, s, x1, y, ft), x1, y, ft, fl)
        node(e, (y1 < 1080 : U32), isflat(fl, s, x, y1, ft), x, y1, ft, fl)
        node(e, ((x1 < 1920) && (y1 < 1080) : U32), isflat(fl, s, x1, y1, ft), x1, y1, ft, fl)
      Qua{a, b, c, d}

def frame(+ft: F32, +fl: Bool) -> Image:
  node(7n, True{}, isflat(fl, 2048, 0, 0, ft), 0, 0, ft, fl)

# validation: on-screen area-weighted colour sum (CPU, no bang)
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

def loop(+fl: Bool, +n: Nat) -> IO(Unit):
  match n:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      do IO<Unit>:
        +t0 : U32 <- Clock.us()
        img : Image <- IO.pure(Image, frame!(F32.from_nat(p), fl))
        +t1 : U32 <- Clock.us()
        u : Unit <- IO.pure(Unit, Image.drop!(img))
        +t2 : U32 <- Clock.us()
        IO.print("fl " ++ Bool.show(fl) ++ " render_us " ++ U32.show((t1 - t0 : U32)) ++ " drop_us " ++ U32.show((t2 - t1 : U32)))
        loop(fl, p)

def check(+fl: Bool) -> IO(Unit):
  do IO<Unit>:
    +img : Image <- IO.pure(Image, frame!(7.0, fl))
    IO.print("fl " ++ Bool.show(fl) ++ " isum " ++ U32.show(isum(img, 2048, 0, 0)) ++ " leaves " ++ U32.show(leaves(img)))

def main() -> IO(Unit):
  do IO<Unit>:
    check(False{})
    check(True{})
