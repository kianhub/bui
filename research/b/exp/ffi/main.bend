# FFI probes: (1) a foreign effect that calls CoreText (an Apple
# framework) to measure a string; (2) a foreign effect that reads an
# Array<U32> in place from C and hands it back; (3) the cost of a
# trivial foreign effect round trip through the event loop.
import Base

def Text.width(text: String, size: U32) -> IO(U32):
  import "./ffi.c"
  import "./ffi.js"

def Px.sum(a: Array<U32>) -> IO(Array<U32> & U32):
  import "./ffi.c"
  import "./ffi.js"

def Nop.call(x: U32) -> IO(U32):
  import "./ffi.c"
  import "./ffi.js"

def spin(n: Nat, +acc: U32) -> IO(U32):
  match n:
    case 0n:
      IO.pure(U32, acc)
    case 1n+k:
      do IO<U32>:
        y : U32 <- Nop.call(acc)
        spin(k, y)

def fill(n: Nat, +i: U32, a: Array<U32>) -> Array<U32>:
  match n:
    case 0n:
      a
    case 1n+k:
      fill(k, U32.inc(i), Array.set(U32, a, i, i))

def main() -> IO(Unit):
  do IO<Unit>:
    w : U32 <- Text.width("Hello, GPUI in Bend", 16)
    IO.print("CoreText width x1000: " ++ U32.show(w))
    r : Array<U32> & U32 <- Px.sum(fill(1024n, 0, [0 : U32*1024n]))
    IO.print("C-side sum of 0..1023: " ++ U32.show(Pair.snd(Array<U32>, U32, r)))
    t0 : Nat <- IO.now()
    v : U32 <- spin(1000000n, 0)
    t1 : Nat <- IO.now()
    IO.print("1e6 foreign round trips: " ++ U32.show(v) ++ " in " ++ Nat.show(Nat.sub(t1, t0)) ++ " ms")
