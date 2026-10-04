# Gap 1b: the CoreText shaping round trip from Bend. A 2,000-char String goes
# through Text.shape (shape.c): cons-list String -> UTF-8 -> CFString (UTF-16)
# -> CTTypesetter line breaks -> glyph ids, positions, advances -> a Bend
# List<&2, U32> -> decoded into a positioned glyph run (the Run of core.bend).
# Mode A: the whole 2,000 chars in one call, wrapped at 600 pt.
# Mode B: 25 lines of 80 chars, one call per line (re-shaping changed lines).
import Base

def Clock.us() -> IO(U32):
  import "./clock.c"
  import "./clock.js"

def Text.shape(text: String, size: U32, width: U32) -> IO(List<&2, U32>):
  import "./shape.c"
  import "./shape.js"

type Run is Data:
  RNil{}
  RCon{c: U32, x: F32, y: F32, next: Run}

def decode(xs: List<&2, U32>, acc: Run, +n: U32) -> Run & U32:
  match xs:
    case Con{g, Con{+x, Con{+l, Con{a, t}}}}:
      decode(t, RCon{g, (U32.to_f32(x) * 0.015625 : F32), (U32.to_f32(l) * 16.8 : F32), acc}, (n + 1 : U32))
    case _:
      (acc, n)

def Run.sink(r: Run) -> Unit:
  match r:
    case RNil{}:
      Unit{}
    case RCon{_, _, _, next}:
      Run.sink(next)

def text(+n: Nat) -> String:
  String.take(String.repeat("The quick brown fox jumps over the lazy dog, 0123456789. ", 40n), n)

def line(+i: U32) -> String:
  String.take("Line " ++ U32.show(i) ++ ": The quick brown fox jumps over the lazy dog, 0123456789 and more text here.", 80n)

def got.k(u: Unit, +n: U32) -> U32:
  match u:
    case Unit{}:
      n

def got(r: Run & U32) -> U32:
  (run, n) = r
  got.k(Run.sink(run), n)

# one call, the whole text
def mode.a(+i: U32) -> IO(U32):
  do IO<U32>:
    s : String <- IO.pure(String, text(2000n))
    +t0 : U32 <- Clock.us()
    xs : List<&2, U32> <- Text.shape(s, 14, 600)
    +n : U32 <- IO.pure(U32, got(decode(xs, RNil{}, 0)))
    +t1 : U32 <- Clock.us()
    IO.print("A i " ++ U32.show(i) ++ " glyphs " ++ U32.show(n) ++ " round_us " ++ U32.show((t1 - t0 : U32)))
    IO.pure(U32, n)

# one call per line
def lines(+k: Nat, +i: U32, +acc: U32) -> IO(U32):
  match k:
    case 0n:
      IO.pure(U32, acc)
    case 1n+p:
      do IO<U32>:
        xs : List<&2, U32> <- Text.shape(line((i + U32.from_nat(p) : U32)), 14, 100000)
        +n : U32 <- IO.pure(U32, got(decode(xs, RNil{}, 0)))
        lines(p, i, (acc + n : U32))

def mode.b(+i: U32) -> IO(U32):
  do IO<U32>:
    +t0 : U32 <- Clock.us()
    +n : U32 <- lines(25n, i, 0)
    +t1 : U32 <- Clock.us()
    IO.print("B i " ++ U32.show(i) ++ " glyphs " ++ U32.show(n) ++ " round_us " ++ U32.show((t1 - t0 : U32)))
    IO.pure(U32, n)

def loop(+k: Nat, +i: U32) -> IO(Unit):
  match k:
    case 0n:
      IO.print("done")
    case 1n+p:
      do IO<Unit>:
        +a : U32 <- mode.a(i)
        +b : U32 <- mode.b(i)
        loop(p, (i + 1 : U32))

def main() -> IO(Unit):
  loop(110n, 0)
