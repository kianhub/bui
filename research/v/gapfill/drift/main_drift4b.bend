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
