import Base

# 1920x1080 frame, every pixel shaded by Q rounded-rect SDFs blended over a
# background (GPUI quad_fragment-like math), reduced to a U32 checksum.
# 2^14 leaves (one per GPU lane), each a flat loop over 127 pixels.

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
  +a1 = cov(sdf(px, py, (480.0 + ft : F32), 300.0, 400.0, 220.0, 16.0))
  +a2 = cov(sdf(px, py, 1300.0, (500.0 + ft : F32), 360.0, 300.0, 24.0))
  +a3 = cov(sdf(px, py, 960.0, 900.0, (800.0 + ft : F32), 80.0, 40.0))
  +a4 = cov(sdf(px, py, (700.0 - ft : F32), 640.0, 120.0, 120.0, 60.0))
  +r = over(over(over(over(0.10, 0.90, a1), 0.20, a2), 0.95, a3), 0.40, a4)
  +g = over(over(over(over(0.11, 0.90, a1), 0.50, a2), 0.60, a3), 0.80, a4)
  +b = over(over(over(over(0.13, 0.92, a1), 0.90, a2), 0.20, a3), 0.40, a4)
  pack(r, g, b)

def span(n: Nat, +i: U32, +ft: F32, +acc: U32) -> U32:
  match n:
    case 0n:
      acc
    case 1n+p:
      span(p, (i + 1 : U32), ft, (acc * 31 + shade((i % 1920 : U32), (i / 1920 : U32), ft) : U32))

def frame(+d: Nat, +i: U32, +ft: F32) -> U32:
  match d:
    case 0n:
      span(127n, (i * 127 : U32), ft, 0)
    case 1n+p:
      a b = frame(p, (i * 2 : U32), ft) frame(p, (i * 2 + 1 : U32), ft)
      (a + b : U32)

def loop(+n: Nat, +acc: U32) -> IO(U32):
  match n:
    case 0n:
      IO.pure(U32, acc)
    case 1n+p:
      do IO<U32>:
        +t0 : U32 <- Clock.us()
        +s : U32 <- IO.pure(U32, frame!(14n, 0, F32.from_nat(p)))
        +t1 : U32 <- Clock.us()
        IO.print("frame_us " ++ U32.show((t1 - t0 : U32)) ++ " sum " ++ U32.show(s))
        loop(p, (acc + s : U32))

def main() -> IO(Unit):
  do IO<Unit>:
    t0 : U32 <- Clock.us()
    total : U32 <- loop(40n, 0)
    t1 : U32 <- Clock.us()
    IO.print("total " ++ U32.show(total) ++ " all_us " ++ U32.show((t1 - t0 : U32)))
