# Gap 1: the framework core of v/bend-language/sketch/ui.bend, timed per frame
# over a real element tree. Extensions over the sketch:
# - Text wraps: greedy word wrap over per-char advances (a proportional
#   advance table standing in for cached CoreText metrics), producing a
#   positioned glyph run per text node (GPUI's WrappedLine);
# - ScrollView applies its offset;
# - a paint pass emits a GPUI-style flat Scene (quads + glyph sprites) and the
#   hitbox list (GPUI registers hitboxes in prepaint/paint);
# - hit test + dispatch of the Msg under the mouse.
# No @unsafe. Children are List<&2, Node>; recursion is on forests.
import Base

def Clock.us() -> IO(U32):
  import "./clock.c"
  import "./clock.js"

# Geometry and style
# ------------------

type Rect is Data:
  Rect{x: F32, y: F32, w: F32, h: F32}

type Axis is Data:
  Row{}
  Col{}

type Justify is Data:
  JStart{}
  JCenter{}
  JEnd{}
  JBetween{}

type Align is Data:
  AStart{}
  ACenter{}
  AEnd{}
  AStretch{}

type Len is Data:
  Auto{}
  Px{v: F32}

type Style is Data:
  Style{axis: Axis, justify: Justify, align: Align, w: Len, h: Len,
    grow: F32, pad: F32, gap: F32, bg: U32}

type Msg is Data:
  Inc{id: U32, by: U32}
  Dec{id: U32}
  Reset{id: U32}
  Toggle{id: U32}
  SetLevel{id: U32, v: F32}
  Focus{elem: U32}

# Element tree: 20 kinds (Text gains a wrap width)
type Node is Data:
  Div{st: Style, kids: List<&2, Node>}
  ScrollView{st: Style, off: F32, kids: List<&2, Node>}
  Overlay{st: Style, kids: List<&2, Node>}
  Text{st: Style, s: String, size: F32, wrap: F32}
  Label{st: Style, s: String}
  Heading{st: Style, s: String}
  Link{st: Style, s: String, on_click: Msg}
  Button{st: Style, label: String, on_click: Msg}
  IconButton{st: Style, icon: U32, on_click: Msg}
  Checkbox{st: Style, on: Bool, on_click: Msg}
  Switch{st: Style, on: Bool, on_click: Msg}
  Slider{st: Style, v: F32, on_click: Msg}
  Input{st: Style, text: String, focused: Bool, on_click: Msg}
  Img{st: Style, w: F32, h: F32, tex: U32}
  Icon{st: Style, glyph: U32}
  Spacer{st: Style}
  Divider{st: Style}
  Badge{st: Style, n: U32}
  Progress{st: Style, v: F32}
  Canvas{st: Style, w: F32, h: F32, seed: U32}

# A positioned glyph run (x, y relative to the text box)
type Run is Data:
  RNil{}
  RCon{c: U32, x: F32, y: F32, next: Run}

type Paint is Data:
  PNone{}
  PFill{color: U32}
  PRun{run: Run, color: U32}
  PBar{v: F32, color: U32}

type M is Data:
  M{st: Style, iw: F32, ih: F32, paint: Paint, hit: Maybe<&2, Msg>,
    stack: Bool, scroll: F32, kids: List<&2, M>}

type L is Data:
  L{r: Rect, paint: Paint, hit: Maybe<&2, Msg>, kids: List<&2, L>}

type Tot is Data:
  Tot{main: F32, cross: F32, grow: F32, n: U32}

type Ctx is Data:
  Ctx{axis: Axis, align: Align, x: F32, y: F32, w: F32, h: F32,
    per_grow: F32, gap: F32, start: F32, stack: Bool}

type Hit is Data:
  Hit{r: Rect, m: Msg}

# Small helpers
# -------------

def fpick(c: Bool, a: F32, b: F32) -> F32:
  match c:
    case True{}:
      a
    case False{}:
      b

def len_or(l: Len, d: F32) -> F32:
  match l:
    case Auto{}:
      d
    case Px{v}:
      v

def main_of(a: Axis, w: F32, h: F32) -> F32:
  match a:
    case Row{}:
      w
    case Col{}:
      h

def cross_of(a: Axis, w: F32, h: F32) -> F32:
  match a:
    case Row{}:
      h
    case Col{}:
      w

def plain() -> Style:
  Style{Row{}, JStart{}, AStart{}, Auto{}, Auto{}, 0.0, 0.0, 0.0, 0}

# Text: advances and greedy word wrap
# -----------------------------------

# em fraction of a char (a proportional table, as cached font metrics give)
def adv(+c: U32) -> F32:
  fpick((c < 33 : U32), 0.28,
    fpick((U32.is_eq(c, 105) || U32.is_eq(c, 108) || U32.is_eq(c, 106) || U32.is_eq(c, 116) || U32.is_eq(c, 102) || U32.is_eq(c, 46) || U32.is_eq(c, 44) || U32.is_eq(c, 58) : U32), 0.30,
      fpick((U32.is_eq(c, 109) || U32.is_eq(c, 119) : U32), 0.86,
        fpick(((c > 64) && (c < 91) : U32), 0.68,
          fpick(((c > 47) && (c < 58) : U32), 0.56, 0.52)))))

def is_sp(+c: U32) -> Bool:
  (c < 33 : U32)

type Wd is Data:
  Wd{cs: Run, w: F32, rest: String}

# one word: c is the char already taken off the string, sp whether it is a
# space (the word ends there, the space consumed)
def wword(s: String, sp: Bool, +c: U32, +size: F32, +x: F32, acc: Run) -> Wd:
  match s sp:
    case _ True{}:
      Wd{acc, x, s}
    case SNil{} False{}:
      Wd{RCon{c, x, 0.0, acc}, (x + adv(c) * size : F32), SNil{}}
    case SCon{Chr{+d}, t} False{}:
      wword(t, is_sp(d), d, size, (x + adv(c) * size : F32), RCon{c, x, 0.0, acc})

def shift(cs: Run, +ox: F32, +oy: F32, acc: Run) -> Run:
  match cs:
    case RNil{}:
      acc
    case RCon{c, +x, +y, t}:
      shift(t, ox, oy, RCon{c, (x + ox : F32), (y + oy : F32), acc})

type WR is Data:
  WR{run: Run, x: F32, y: F32, w: F32, n: U32}

def wplace(cs: Run, +ww: F32, st: WR, +size: F32, +maxw: F32, +lh: F32) -> WR:
  WR{acc, +x, +y, +w, +n} = st
  +brk = ((x > 0.0) && ((x + ww) > maxw) : F32)
  +nx = fpick(brk, 0.0, x)
  +ny = fpick(brk, (y + lh : F32), y)
  WR{shift(cs, nx, ny, acc), (nx + ww + 0.28 * size : F32), ny,
    F32.max(w, (nx + ww : F32)), (n + 1 : U32)}

# fuel bounds the words (each takes at least one char)
def wrap(fuel: Nat, wd: Wd, +size: F32, +maxw: F32, +lh: F32, st: WR) -> WR:
  match fuel wd:
    case 0n _:
      st
    case 1n+p Wd{cs, +ww, rest}:
      match rest:
        case SNil{}:
          wplace(cs, ww, st, size, maxw, lh)
        case SCon{Chr{+c}, t}:
          wrap(p, wword(t, is_sp(c), c, size, 0.0, RNil{}), size, maxw, lh, wplace(cs, ww, st, size, maxw, lh))

def word0(s: String, +size: F32) -> Wd:
  match s:
    case SNil{}:
      Wd{RNil{}, 0.0, SNil{}}
    case SCon{Chr{+c}, t}:
      wword(t, is_sp(c), c, size, 0.0, RNil{})

# Measure: Node forest -> M forest (bottom-up intrinsic sizes)
# -------------------------------------------------------------

def grow_of(st: Style) -> F32:
  Style{ax, j, al, w, h, grow, pad, gap, bg} = st
  grow

def tot(ks: List<&2, M>, +a: Axis, acc: Tot) -> Tot:
  match ks acc:
    case Nil{} _:
      acc
    case M{st, +iw, +ih, p, h, s, sc, k} <> t Tot{m, c, g, n}:
      tot(t, a, Tot{(m + main_of(a, iw, ih) : F32),
        F32.max(c, cross_of(a, iw, ih)), (g + grow_of(st) : F32), (n + 1 : U32)})

def stack_wh(ks: List<&2, M>, w: F32, h: F32) -> Rect:
  match ks:
    case Nil{}:
      Rect{0.0, 0.0, w, h}
    case M{st, iw, ih, p, hh, s, sc, k} <> t:
      stack_wh(t, F32.max(w, iw), F32.max(h, ih))

def gaps(+gap: F32, n: U32) -> F32:
  (gap * U32.to_f32(U32.sub(U32.max(n, 1), 1)) : F32)

def flow_box.k(+st: Style, kids: List<&2, M>, paint: Paint,
  hit: Maybe<&2, Msg>, scroll: F32, t: Tot) -> M:
  Style{+ax, j, al, w, h, grow, +pad, +gap, bg} = st
  Tot{m, c, g, n} = t
  +mm = (m + gaps(gap, n) + 2.0 * pad : F32)
  +cc = (c + 2.0 * pad : F32)
  M{st, len_or(w, main_of(ax, mm, cc)), len_or(h, cross_of(ax, mm, cc)),
    paint, hit, False{}, scroll, kids}

def axis_of(st: Style) -> Axis:
  Style{ax, j, al, w, h, grow, pad, gap, bg} = st
  ax

def flow_box(+st: Style, +kids: List<&2, M>, paint: Paint,
  hit: Maybe<&2, Msg>, scroll: F32) -> M:
  flow_box.k(st, kids, paint, hit, scroll, tot(kids, axis_of(st), Tot{0.0, 0.0, 0.0, 0}))

def stack_box.k(+st: Style, kids: List<&2, M>, r: Rect) -> M:
  Style{ax, j, al, w, h, grow, +pad, gap, bg} = st
  Rect{x, y, sw, sh} = r
  M{st, len_or(w, (sw + 2.0 * pad : F32)), len_or(h, (sh + 2.0 * pad : F32)),
    PFill{bg}, None{}, True{}, 0.0, kids}

def stack_box(+st: Style, +kids: List<&2, M>) -> M:
  stack_box.k(st, kids, stack_wh(kids, 0.0, 0.0))

def leaf(+st: Style, iw: F32, ih: F32, paint: Paint, hit: Maybe<&2, Msg>) -> M:
  Style{ax, j, al, w, h, grow, +pad, gap, bg} = st
  M{st, len_or(w, (iw + 2.0 * pad : F32)), len_or(h, (ih + 2.0 * pad : F32)),
    paint, hit, False{}, 0.0, Nil{}}

def bg_of(st: Style) -> U32:
  Style{ax, j, al, w, h, grow, pad, gap, bg} = st
  bg

def nowrap() -> F32:
  1000000000.0

# a text leaf's (w, h, run)
def tbox.k(st: Style, r: WR, +lh: F32, color: U32, hit: Maybe<&2, Msg>) -> M:
  WR{run, x, +y, +w, n} = r
  leaf(st, w, (y + lh : F32), PRun{run, color}, hit)

def tbox(st: Style, s: String, +size: F32, +maxw: F32, color: U32, hit: Maybe<&2, Msg>) -> M:
  +lh = (size * 1.2 : F32)
  tbox.k(st, wrap(4096n, word0(s, size), size, maxw, lh, WR{RNil{}, 0.0, 0.0, 0.0, 0}), lh, color, hit)

def measure(ns: List<&2, Node>) -> List<&2, M>:
  match ns:
    case Nil{}:
      Nil{}
    case Div{+st, ks} <> t:
      flow_box(st, measure(ks), PFill{bg_of(st)}, None{}, 0.0) <> measure(t)
    case ScrollView{+st, off, ks} <> t:
      flow_box(st, measure(ks), PFill{bg_of(st)}, None{}, off) <> measure(t)
    case Overlay{st, ks} <> t:
      stack_box(st, measure(ks)) <> measure(t)
    case Text{st, s, size, wrap} <> t:
      tbox(st, s, size, wrap, 15790320, None{}) <> measure(t)
    case Label{st, s} <> t:
      tbox(st, s, 14.0, nowrap(), 13421772, None{}) <> measure(t)
    case Heading{st, s} <> t:
      tbox(st, s, 24.0, nowrap(), 16777215, None{}) <> measure(t)
    case Link{st, s, m} <> t:
      tbox(st, s, 14.0, nowrap(), 6724095, Some{m}) <> measure(t)
    case Button{st, s, m} <> t:
      tbox(st, s, 14.0, nowrap(), 16777215, Some{m}) <> measure(t)
    case IconButton{st, i, m} <> t:
      leaf(st, 16.0, 16.0, PFill{i}, Some{m}) <> measure(t)
    case Checkbox{st, on, m} <> t:
      leaf(st, 16.0, 16.0, PFill{0}, Some{m}) <> measure(t)
    case Switch{st, on, m} <> t:
      leaf(st, 32.0, 16.0, PFill{0}, Some{m}) <> measure(t)
    case Slider{st, +v, m} <> t:
      leaf(st, 120.0, 16.0, PBar{v, 3381759}, Some{m}) <> measure(t)
    case Input{st, s, f, m} <> t:
      tbox(st, s, 14.0, nowrap(), 16777215, Some{m}) <> measure(t)
    case Img{st, w, h, tex} <> t:
      leaf(st, w, h, PFill{tex}, None{}) <> measure(t)
    case Icon{st, g} <> t:
      leaf(st, 16.0, 16.0, PFill{g}, None{}) <> measure(t)
    case Spacer{st} <> t:
      leaf(st, 0.0, 0.0, PNone{}, None{}) <> measure(t)
    case Divider{st} <> t:
      leaf(st, 1.0, 1.0, PFill{4473924}, None{}) <> measure(t)
    case Badge{st, +n} <> t:
      tbox(st, U32.show(n), 12.0, nowrap(), 16777215, None{}) <> measure(t)
    case Progress{st, +v} <> t:
      leaf(st, 120.0, 6.0, PBar{v, 65280}, None{}) <> measure(t)
    case Canvas{st, w, h, seed} <> t:
      leaf(st, w, h, PFill{seed}, None{}) <> measure(t)

# Place: M forest -> L forest (top-down flexbox)
# ----------------------------------------------

def align_off(al: Align, +room: F32) -> F32:
  match al:
    case AStart{}:
      0.0
    case ACenter{}:
      (room / 2.0 : F32)
    case AEnd{}:
      room
    case AStretch{}:
      0.0

def is_stretch(al: Align) -> Bool:
  match al:
    case AStretch{}:
      True{}
    case _:
      False{}

def kid_rect.fin(stack: Bool, axis: Axis, +x: F32, +y: F32, w: F32, h: F32,
  +cur: F32, +off: F32, +main: F32, +cross: F32) -> Rect:
  match stack axis:
    case True{} _:
      Rect{x, y, w, h}
    case False{} Row{}:
      Rect{cur, (y + off : F32), main, cross}
    case False{} Col{}:
      Rect{(x + off : F32), cur, cross, main}

def kid_rect(+c: Ctx, +cur: F32, st: Style, +iw: F32, +ih: F32) -> Rect:
  Ctx{+axis, +al, +x, +y, +w, +h, +pg, gap, start, stack} = c
  +inner_cross = cross_of(axis, w, h)
  +main = (main_of(axis, iw, ih) + grow_of(st) * pg : F32)
  +cross = fpick(is_stretch(al), inner_cross, cross_of(axis, iw, ih))
  kid_rect.fin(stack, axis, x, y, w, h, cur,
    align_off(al, (inner_cross - cross : F32)), main, cross)

def next_cur(+c: Ctx, +cur: F32, +r: Rect) -> F32:
  Ctx{axis, al, x, y, w, h, pg, +gap, start, stack} = c
  Rect{rx, ry, rw, rh} = r
  fpick(stack, cur, (cur + main_of(axis, rw, rh) + gap : F32))

def justify(j: Justify, +free: F32, +gap: F32, +n: U32, +grow: F32) -> Rect:
  match j:
    case JStart{}:
      Rect{0.0, 0.0, gap, 0.0}
    case JCenter{}:
      Rect{fpick((grow > 0.0 : F32), 0.0, (free / 2.0 : F32)), 0.0, gap, 0.0}
    case JEnd{}:
      Rect{fpick((grow > 0.0 : F32), 0.0, free), 0.0, gap, 0.0}
    case JBetween{}:
      Rect{0.0, 0.0, fpick((n > 1 : U32),
        (gap + free / U32.to_f32(U32.sub(n, 1)) : F32), gap), 0.0}

def enter.fin(+ax: Axis, al: Align, +x0: F32, +y0: F32, iw: F32, ih: F32,
  pg: F32, stack: Bool, +scroll: F32, jg: Rect) -> Ctx:
  Rect{off, z, gap2, zz} = jg
  Ctx{ax, al, x0, y0, iw, ih, pg, gap2, (main_of(ax, x0, y0) + off - scroll : F32),
    stack}

def enter.k(st: Style, stack: Bool, +scroll: F32, r: Rect, t: Tot) -> Ctx:
  Style{+ax, j, al, w, h, grow, +pad, +gap, bg} = st
  Rect{x, y, +rw, +rh} = r
  Tot{m, c, +g, +n} = t
  +iw = F32.max(0.0, (rw - 2.0 * pad : F32))
  +ih = F32.max(0.0, (rh - 2.0 * pad : F32))
  +free = F32.max(0.0, (main_of(ax, iw, ih) - m - gaps(gap, n) : F32))
  +pg = fpick((g > 0.0 : F32), (free / g : F32), 0.0)
  enter.fin(ax, al, (x + pad : F32), (y + pad : F32), iw, ih, pg, stack, scroll,
    justify(j, free, gap, n, g))

def enter(+st: Style, stack: Bool, +scroll: F32, r: Rect, kids: List<&2, M>) -> Ctx:
  enter.k(st, stack, scroll, r, tot(kids, axis_of(st), Tot{0.0, 0.0, 0.0, 0}))

def ctx_start(c: Ctx) -> F32:
  Ctx{axis, al, x, y, w, h, pg, gap, start, stack} = c
  start

def place(ms: List<&2, M>, +c: Ctx, +cur: F32) -> List<&2, L>:
  match ms:
    case Nil{}:
      Nil{}
    case M{+st, +iw, +ih, paint, hit, stk, +sc, +kids} <> t:
      +r = kid_rect(c, cur, st, iw, ih)
      +cc = enter(st, stk, sc, r, kids)
      L{r, paint, hit, place(kids, cc, ctx_start(cc))}
        <> place(t, c, next_cur(c, cur, r))

def root_ctx(+w: F32, +h: F32) -> Ctx:
  Ctx{Col{}, AStretch{}, 0.0, 0.0, w, h, 0.0, 0.0, 0.0, False{}}

def layout(n: Node, +w: F32, +h: F32) -> List<&2, L>:
  place(measure([n]), root_ctx(w, h), 0.0)

# Paint: L forest -> flat Scene (quads, glyph sprites) + hitboxes
# --------------------------------------------------------------

type Qs is Data:
  QNil{}
  QCons{x0: F32, y0: F32, x1: F32, y1: F32, r: F32, bw: F32, fc: U32, bc: U32, next: Qs}

type Ss is Data:
  SpNil{}
  SpCon{x: F32, y: F32, gid: U32, c: U32, next: Ss}

type Scene is Data:
  Scene{qs: Qs, ss: Ss, hs: List<&2, Hit>, nq: U32, ns: U32}

def glyphs(run: Run, +ox: F32, +oy: F32, +col: U32, acc: Ss, +n: U32) -> Ss & U32:
  match run:
    case RNil{}:
      (acc, n)
    case RCon{+c, x, y, t}:
      glyphs(t, ox, oy, col, SpCon{(ox + x : F32), (oy + y : F32), (c % 96 : U32), col, acc}, (n + 1 : U32))

def paint.run(r: Ss & U32, qs: Qs, hs: List<&2, Hit>, +nq: U32) -> Scene:
  (ss, ns) = r
  Scene{qs, ss, hs, nq, ns}

def paint.hit(h: Maybe<&2, Msg>, +r: Rect, hs: List<&2, Hit>) -> List<&2, Hit>:
  match h:
    case None{}:
      hs
    case Some{m}:
      Hit{r, m} <> hs

def paint.none(h: Maybe<&2, Msg>, +r: Rect, sc: Scene) -> Scene:
  Scene{qs, ss, hs, nq, ns} = sc
  Scene{qs, ss, paint.hit(h, r, hs), nq, ns}

def paint.fill(+r: Rect, +c: U32, +bc: U32, +rad: F32, +bw: F32, +frac: F32, h: Maybe<&2, Msg>, sc: Scene) -> Scene:
  Rect{+x, +y, +w, +hh} = r
  Scene{qs, ss, hs, nq, ns} = sc
  Scene{QCons{x, y, (x + w * frac : F32), (y + hh : F32), rad, bw, c, bc, qs}, ss, paint.hit(h, r, hs), (nq + 1 : U32), ns}

def paint.text(+r: Rect, run: Run, +c: U32, h: Maybe<&2, Msg>, sc: Scene) -> Scene:
  Rect{+x, +y, w, hh} = r
  Scene{qs, ss, hs, nq, ns} = sc
  paint.run(glyphs(run, x, y, c, ss, ns), qs, paint.hit(h, r, hs), nq)

def paint(+r: Rect, p: Paint, h: Maybe<&2, Msg>, sc: Scene) -> Scene:
  match p:
    case PNone{}:
      paint.none(h, r, sc)
    case PFill{+c}:
      paint.fill(r, c, 10526880, 4.0, 1.0, 1.0, h, sc)
    case PBar{v, +c}:
      paint.fill(r, c, c, 2.0, 0.0, v, h, sc)
    case PRun{run, c}:
      paint.text(r, run, c, h, sc)

def emit(ls: List<&2, L>, sc: Scene) -> Scene:
  match ls:
    case Nil{}:
      sc
    case L{r, p, h, kids} <> t:
      emit(t, emit(kids, paint(r, p, h, sc)))

# Hit test and dispatch
# ---------------------

def inside(r: Rect, +px: F32, +py: F32) -> Bool:
  Rect{+x, +y, w, h} = r
  ((px >= x) && (px < x + w) && (py >= y) && (py < y + h) : F32)

def find_hit.k(c: Bool, m: Msg, rest: Maybe<&2, Msg>) -> Maybe<&2, Msg>:
  match c:
    case True{}:
      Some{m}
    case False{}:
      rest

# hitboxes are newest-first, so the first inside is the top-most
def find_hit(hs: List<&2, Hit>, +px: F32, +py: F32) -> Maybe<&2, Msg>:
  match hs:
    case Nil{}:
      None{}
    case Hit{r, m} <> t:
      find_hit.k(inside(r, px, py), m, find_hit(t, px, py))

def update(m: Msg, +c: U32) -> U32:
  match m:
    case Inc{i, by}:
      (c + by : U32)
    case Dec{i}:
      U32.sub(c, 1)
    case Reset{i}:
      0
    case other:
      c

def apply(m: Maybe<&2, Msg>, +c: U32) -> U32:
  match m:
    case None{}:
      c
    case Some{msg}:
      update(msg, c)

# View: state -> element tree (a scrolling list of rows)
# -----------------------------------------------------

def rowst() -> Style:
  Style{Row{}, JStart{}, ACenter{}, Auto{}, Auto{}, 0.0, 6.0, 12.0, 3158064}

def grow1() -> Style:
  Style{Row{}, JStart{}, AStart{}, Auto{}, Auto{}, 1.0, 0.0, 0.0, 0}

def btnst() -> Style:
  Style{Row{}, JStart{}, AStart{}, Auto{}, Auto{}, 0.0, 6.0, 0.0, 4210816}

def rowtext(+i: U32, +c: U32) -> String:
  "Row " ++ U32.show(i) ++ ": the quick brown fox jumps over the lazy dog, item "
    ++ U32.show((i * 7 + c : U32)) ++ " of the list"

def rows(n: Nat, +i: U32, +c: U32) -> List<&2, Node>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      Div{rowst(), [
        Text{plain(), rowtext(i, c), 14.0, 300.0},
        Spacer{grow1()},
        Button{btnst(), "Open", Inc{i, 1}}]} <> rows(p, (i + 1 : U32), c)

def view(+nrows: U32, +c: U32, +scroll: F32) -> Node:
  ScrollView{Style{Col{}, JStart{}, AStretch{}, Px{1920.0}, Px{1200.0}, 0.0, 8.0, 4.0, 2105376},
    scroll, rows(U32.to_nat(nrows), 0, c)}

# a flat count of elements and glyphs, to check the tree
def count(ns: List<&2, Node>, +n: U32) -> U32:
  match ns:
    case Nil{}:
      n
    case Div{st, ks} <> t:
      count(t, count(ks, (n + 1 : U32)))
    case ScrollView{st, o, ks} <> t:
      count(t, count(ks, (n + 1 : U32)))
    case Overlay{st, ks} <> t:
      count(t, count(ks, (n + 1 : U32)))
    case other <> t:
      count(t, (n + 1 : U32))

def Qs.sink(ts: Qs) -> Unit:
  match ts:
    case QNil{}:
      Unit{}
    case QCons{_, _, _, _, _, _, _, _, next}:
      Qs.sink(next)

def Ss.sink(ss: Ss) -> Unit:
  match ss:
    case SpNil{}:
      Unit{}
    case SpCon{_, _, _, _, next}:
      Ss.sink(next)

def u3(a: Unit, b: Unit) -> Unit:
  match a b:
    case Unit{} Unit{}:
      Unit{}

def scene.sink(sc: Scene) -> Unit:
  Scene{qs, ss, hs, nq, ns} = sc
  u3(Qs.sink(qs), Ss.sink(ss))
