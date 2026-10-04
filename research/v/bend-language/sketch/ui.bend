# A GPUI-shaped UI core in Bend 2, with no @unsafe:
# - 20 element kinds in one Data tree (Node), children as List<&2, Node>
# - defunctionalized listeners: a Msg value per clickable element
# - an id-keyed entity store (Base Array<Ent>, indexed by U32 entity id)
# - a sparse U32-keyed element-state map written from scratch (IMap)
# - a flexbox subset: row/column, padding, gap, flex-grow, justify, align,
#   fixed or auto sizes, and stacked overlays
# - measure (bottom-up) -> place (top-down) -> hit list -> dispatch
# Mutual recursion is avoided by recursing on a forest (List<&2, Node>):
# a container's kids and its later siblings are both sub-terms of the list.
import Base

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

# Messages (what a GPUI listener closure becomes)
# -----------------------------------------------

type Msg is Data:
  Inc{id: U32, by: U32}
  Dec{id: U32}
  Reset{id: U32}
  Toggle{id: U32}
  SetLevel{id: U32, v: F32}
  Focus{elem: U32}

# Element tree: 20 kinds
# ----------------------

type Node is Data:
  Div{st: Style, kids: List<&2, Node>}
  ScrollView{st: Style, off: F32, kids: List<&2, Node>}
  Overlay{st: Style, kids: List<&2, Node>}
  Text{st: Style, s: String, size: F32}
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

# Measured and placed trees
# -------------------------

type Paint is Data:
  PNone{}
  PFill{color: U32}
  PText{s: String, size: F32, color: U32}
  PBar{v: F32, color: U32}

type M is Data:
  M{st: Style, iw: F32, ih: F32, paint: Paint, hit: Maybe<&2, Msg>,
    stack: Bool, kids: List<&2, M>}

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

def text_w(s: String, +size: F32) -> F32:
  (F32.from_nat(String.length(s)) * size * 0.6 : F32)

def style(axis: Axis, w: Len, h: Len, grow: F32, pad: F32, gap: F32,
  bg: U32) -> Style:
  Style{axis, JStart{}, AStretch{}, w, h, grow, pad, gap, bg}

def plain() -> Style:
  Style{Row{}, JStart{}, AStart{}, Auto{}, Auto{}, 0.0, 0.0, 0.0, 0}

# Measure: Node forest -> M forest (bottom-up intrinsic sizes)
# -------------------------------------------------------------

def grow_of(st: Style) -> F32:
  Style{ax, j, al, w, h, grow, pad, gap, bg} = st
  grow

def tot(ks: List<&2, M>, +a: Axis, acc: Tot) -> Tot:
  match ks acc:
    case Nil{} _:
      acc
    case M{st, +iw, +ih, p, h, s, k} <> t Tot{m, c, g, n}:
      tot(t, a, Tot{(m + main_of(a, iw, ih) : F32),
        F32.max(c, cross_of(a, iw, ih)), (g + grow_of(st) : F32), (n + 1 : U32)})

def stack_wh(ks: List<&2, M>, w: F32, h: F32) -> Rect:
  match ks:
    case Nil{}:
      Rect{0.0, 0.0, w, h}
    case M{st, iw, ih, p, hh, s, k} <> t:
      stack_wh(t, F32.max(w, iw), F32.max(h, ih))

def gaps(+gap: F32, n: U32) -> F32:
  (gap * U32.to_f32(U32.sub(U32.max(n, 1), 1)) : F32)

def flow_box.k(+st: Style, kids: List<&2, M>, paint: Paint,
  hit: Maybe<&2, Msg>, t: Tot) -> M:
  Style{+ax, j, al, w, h, grow, +pad, +gap, bg} = st
  Tot{m, c, g, n} = t
  +mm = (m + gaps(gap, n) + 2.0 * pad : F32)
  +cc = (c + 2.0 * pad : F32)
  M{st, len_or(w, main_of(ax, mm, cc)), len_or(h, cross_of(ax, mm, cc)),
    paint, hit, False{}, kids}

def axis_of(st: Style) -> Axis:
  Style{ax, j, al, w, h, grow, pad, gap, bg} = st
  ax

def flow_box(+st: Style, +kids: List<&2, M>, paint: Paint,
  hit: Maybe<&2, Msg>) -> M:
  flow_box.k(st, kids, paint, hit, tot(kids, axis_of(st), Tot{0.0, 0.0, 0.0, 0}))

def stack_box.k(+st: Style, kids: List<&2, M>, r: Rect) -> M:
  Style{ax, j, al, w, h, grow, +pad, gap, bg} = st
  Rect{x, y, sw, sh} = r
  M{st, len_or(w, (sw + 2.0 * pad : F32)), len_or(h, (sh + 2.0 * pad : F32)),
    PFill{bg}, None{}, True{}, kids}

def stack_box(+st: Style, +kids: List<&2, M>) -> M:
  stack_box.k(st, kids, stack_wh(kids, 0.0, 0.0))

def leaf(+st: Style, iw: F32, ih: F32, paint: Paint, hit: Maybe<&2, Msg>) -> M:
  Style{ax, j, al, w, h, grow, +pad, gap, bg} = st
  M{st, len_or(w, (iw + 2.0 * pad : F32)), len_or(h, (ih + 2.0 * pad : F32)),
    paint, hit, False{}, Nil{}}

def bg_of(st: Style) -> U32:
  Style{ax, j, al, w, h, grow, pad, gap, bg} = st
  bg

def measure(ns: List<&2, Node>) -> List<&2, M>:
  match ns:
    case Nil{}:
      Nil{}
    case Div{+st, ks} <> t:
      flow_box(st, measure(ks), PFill{bg_of(st)}, None{}) <> measure(t)
    case ScrollView{+st, off, ks} <> t:
      flow_box(st, measure(ks), PFill{bg_of(st)}, None{}) <> measure(t)
    case Overlay{st, ks} <> t:
      stack_box(st, measure(ks)) <> measure(t)
    case Text{st, +s, +size} <> t:
      leaf(st, text_w(s, size), (size * 1.2 : F32), PText{s, size, 15790320},
        None{}) <> measure(t)
    case Label{st, +s} <> t:
      leaf(st, text_w(s, 14.0), 16.8, PText{s, 14.0, 13421772}, None{})
        <> measure(t)
    case Heading{st, +s} <> t:
      leaf(st, text_w(s, 24.0), 28.8, PText{s, 24.0, 16777215}, None{})
        <> measure(t)
    case Link{st, +s, m} <> t:
      leaf(st, text_w(s, 14.0), 16.8, PText{s, 14.0, 6724095}, Some{m})
        <> measure(t)
    case Button{st, +s, m} <> t:
      leaf(st, text_w(s, 14.0), 16.8, PText{s, 14.0, 16777215}, Some{m})
        <> measure(t)
    case IconButton{st, i, m} <> t:
      leaf(st, 16.0, 16.0, PFill{i}, Some{m}) <> measure(t)
    case Checkbox{st, on, m} <> t:
      leaf(st, 16.0, 16.0, PFill{0}, Some{m}) <> measure(t)
    case Switch{st, on, m} <> t:
      leaf(st, 32.0, 16.0, PFill{0}, Some{m}) <> measure(t)
    case Slider{st, +v, m} <> t:
      leaf(st, 120.0, 16.0, PBar{v, 3381759}, Some{m}) <> measure(t)
    case Input{st, +s, f, m} <> t:
      leaf(st, F32.max(160.0, text_w(s, 14.0)), 16.8,
        PText{s, 14.0, 16777215}, Some{m}) <> measure(t)
    case Img{st, w, h, tex} <> t:
      leaf(st, w, h, PFill{tex}, None{}) <> measure(t)
    case Icon{st, g} <> t:
      leaf(st, 16.0, 16.0, PFill{g}, None{}) <> measure(t)
    case Spacer{st} <> t:
      leaf(st, 0.0, 0.0, PNone{}, None{}) <> measure(t)
    case Divider{st} <> t:
      leaf(st, 1.0, 1.0, PFill{4473924}, None{}) <> measure(t)
    case Badge{st, +n} <> t:
      leaf(st, text_w(U32.show(n), 12.0), 14.4,
        PText{U32.show(n), 12.0, 16777215}, None{}) <> measure(t)
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
  # answers (start offset, gap) packed in a Rect's x and w
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
  pg: F32, stack: Bool, jg: Rect) -> Ctx:
  Rect{off, z, gap2, zz} = jg
  Ctx{ax, al, x0, y0, iw, ih, pg, gap2, (main_of(ax, x0, y0) + off : F32),
    stack}

def enter.k(st: Style, stack: Bool, r: Rect, t: Tot) -> Ctx:
  Style{+ax, j, al, w, h, grow, +pad, +gap, bg} = st
  Rect{x, y, +rw, +rh} = r
  Tot{m, c, +g, +n} = t
  +iw = F32.max(0.0, (rw - 2.0 * pad : F32))
  +ih = F32.max(0.0, (rh - 2.0 * pad : F32))
  +free = F32.max(0.0, (main_of(ax, iw, ih) - m - gaps(gap, n) : F32))
  +pg = fpick((g > 0.0 : F32), (free / g : F32), 0.0)
  enter.fin(ax, al, (x + pad : F32), (y + pad : F32), iw, ih, pg, stack,
    justify(j, free, gap, n, g))

def enter(+st: Style, stack: Bool, r: Rect, kids: List<&2, M>) -> Ctx:
  enter.k(st, stack, r, tot(kids, axis_of(st), Tot{0.0, 0.0, 0.0, 0}))

def ctx_start(c: Ctx) -> F32:
  Ctx{axis, al, x, y, w, h, pg, gap, start, stack} = c
  start

def place(ms: List<&2, M>, +c: Ctx, +cur: F32) -> List<&2, L>:
  match ms:
    case Nil{}:
      Nil{}
    case M{+st, +iw, +ih, paint, hit, stk, +kids} <> t:
      +r = kid_rect(c, cur, st, iw, ih)
      +cc = enter(st, stk, r, kids)
      L{r, paint, hit, place(kids, cc, ctx_start(cc))}
        <> place(t, c, next_cur(c, cur, r))

def root_ctx(+w: F32, +h: F32) -> Ctx:
  Ctx{Col{}, AStretch{}, 0.0, 0.0, w, h, 0.0, 0.0, 0.0, False{}}

# Hit test and dispatch
# ---------------------

def hits(ls: List<&2, L>, acc: List<&2, Hit>) -> List<&2, Hit>:
  match ls:
    case Nil{}:
      acc
    case L{r, p, Some{m}, kids} <> t:
      hits(t, hits(kids, Hit{r, m} <> acc))
    case L{r, p, None{}, kids} <> t:
      hits(t, hits(kids, acc))

def inside(r: Rect, +px: F32, +py: F32) -> Bool:
  Rect{+x, +y, w, h} = r
  ((px >= x) && (px < x + w) && (py >= y) && (py < y + h) : F32)

def find_hit.k(c: Bool, m: Msg, rest: Maybe<&2, Msg>) -> Maybe<&2, Msg>:
  match c:
    case True{}:
      Some{m}
    case False{}:
      rest

def find_hit(hs: List<&2, Hit>, +px: F32, +py: F32) -> Maybe<&2, Msg>:
  match hs:
    case Nil{}:
      None{}
    case Hit{r, m} <> t:
      find_hit.k(inside(r, px, py), m, find_hit(t, px, py))

# Entity store: Array<Ent>, indexed by entity id
# ----------------------------------------------

type Ent is Data:
  Free{}
  Counter{n: U32}
  Check{on: Bool}
  Level{v: F32}

def upick(c: Bool, a: U32, b: U32) -> U32:
  match c:
    case True{}:
      a
    case False{}:
      b

def ent.inc(e: Ent, +by: U32) -> Ent:
  match e:
    case Counter{n}:
      Counter{(n + by : U32)}
    case other:
      other

def ent.dec(e: Ent) -> Ent:
  match e:
    case Counter{+n}:
      Counter{upick((n > 0 : U32), U32.sub(n, 1), 0)}
    case other:
      other

def ent.toggle(e: Ent) -> Ent:
  match e:
    case Check{on}:
      Check{Bool.not(on)}
    case other:
      other

def ent.reset(e: Ent) -> Ent:
  match e:
    case Counter{n}:
      Counter{0}
    case other:
      other

def ent.level(e: Ent, v: F32) -> Ent:
  match e:
    case Level{old}:
      Level{v}
    case other:
      other

def ent.apply(m: Msg, e: Ent) -> Ent:
  match m:
    case Inc{i, by}:
      ent.inc(e, by)
    case Dec{i}:
      ent.dec(e)
    case Reset{i}:
      ent.reset(e)
    case Toggle{i}:
      ent.toggle(e)
    case SetLevel{i, v}:
      ent.level(e, v)
    case Focus{el}:
      e

def msg_id(m: Msg) -> U32:
  match m:
    case Inc{id, by}:
      id
    case Dec{id}:
      id
    case Reset{id}:
      id
    case Toggle{id}:
      id
    case SetLevel{id, v}:
      id
    case Focus{el}:
      3

def store.with(r: Array<Ent> & Ent, +id: U32, m: Msg) -> Array<Ent>:
  (a, e) = r
  Array.set(Ent, a, id, ent.apply(m, e))

# update: the single top-level dispatcher every Msg goes through
def update(+m: Msg, s: Array<Ent>) -> Array<Ent>:
  +id = msg_id(m)
  store.with(Array.get(Ent, s, id), id, m)

def ent.n(e: Ent) -> U32:
  match e:
    case Counter{n}:
      n
    case other:
      0

def ent.on(e: Ent) -> Bool:
  match e:
    case Check{on}:
      on
    case other:
      False{}

def ent.v(e: Ent) -> F32:
  match e:
    case Level{v}:
      v
    case other:
      0.0

# Element state: a sparse U32-keyed map (a bit trie), written from scratch.
# Fuel (bits left) is the decreasing argument, so no @unsafe is needed.
# --------------------------------------------------------------------------

type IMap is Data:
  ITip{}
  ILeaf{k: U32, v: U32}
  INode{lo: IMap, hi: IMap}

def IMap.bit(+k: U32, d: Nat) -> Bool:
  U32.is_eq((U32.shrn(k, d) .&. 1 : U32), 1)

def IMap.pick(b: Bool, lo: IMap, hi: IMap) -> IMap:
  match b:
    case True{}:
      hi
    case False{}:
      lo

def IMap.node(b: Bool, lo: IMap, hi: IMap, sub: IMap) -> IMap:
  match b:
    case True{}:
      INode{lo, sub}
    case False{}:
      INode{sub, hi}

def IMap.leaf_or(same: Bool, a: IMap, b: IMap) -> IMap:
  match same:
    case True{}:
      a
    case False{}:
      b

def IMap.put(fuel: Nat, m: IMap, +d: Nat, +k: U32, +v: U32) -> IMap:
  match fuel m:
    case Zero{} _:
      ILeaf{k, v}
    case Succ{p} ITip{}:
      ILeaf{k, v}
    case Succ{+p} ILeaf{+k2, +v2}:
      IMap.leaf_or(U32.is_eq(k, k2), ILeaf{k, v},
        IMap.put(p, IMap.put(p, INode{ITip{}, ITip{}}, d, k2, v2), d, k, v))
    case Succ{p} INode{+lo, +hi}:
      +b = IMap.bit(k, d)
      IMap.node(b, lo, hi, IMap.put(p, IMap.pick(b, lo, hi), 1n+d, k, v))

def IMap.hit(same: Bool, v: U32) -> Maybe<&2, U32>:
  match same:
    case True{}:
      Some{v}
    case False{}:
      None{}

def IMap.get(fuel: Nat, m: IMap, +d: Nat, +k: U32) -> Maybe<&2, U32>:
  match fuel m:
    case Zero{} _:
      None{}
    case Succ{p} ITip{}:
      None{}
    case Succ{p} ILeaf{k2, v}:
      IMap.hit(U32.is_eq(k, k2), v)
    case Succ{p} INode{lo, hi}:
      IMap.get(p, IMap.pick(IMap.bit(k, d), lo, hi), 1n+d, k)

# View: entity state -> element tree (reads thread the store)
# ------------------------------------------------------------

def pad(p: F32) -> Style:
  Style{Row{}, JStart{}, AStart{}, Auto{}, Auto{}, 0.0, p, 0.0, 3355443}

def row(h: F32, j: Justify, al: Align) -> Style:
  Style{Row{}, j, al, Auto{}, Px{h}, 0.0, 4.0, 8.0, 3158064}

def grow1() -> Style:
  Style{Row{}, JStart{}, AStart{}, Auto{}, Auto{}, 1.0, 0.0, 0.0, 0}

def tree(+c: U32, +on: Bool, +lv: F32) -> Node:
  Div{Style{Col{}, JStart{}, AStretch{}, Auto{}, Auto{}, 0.0, 16.0, 8.0,
    2105376}, [
    Heading{plain(), "Counter"},
    Div{row(40.0, JStart{}, ACenter{}), [
      Button{pad(6.0), "-", Dec{0}},
      Text{pad(6.0), U32.show(c), 14.0},
      Button{pad(6.0), "+", Inc{0, 1}},
      Spacer{grow1()},
      Badge{pad(2.0), c},
      Button{pad(6.0), "reset", Reset{0}}]},
    Div{row(28.0, JStart{}, ACenter{}), [
      Checkbox{plain(), on, Toggle{1}},
      Label{plain(), "enabled"},
      Switch{plain(), on, Toggle{1}}]},
    Div{row(24.0, JBetween{}, AStretch{}), [
      Slider{plain(), lv, SetLevel{2, 0.75}},
      Progress{plain(), lv}]},
    Overlay{pad(0.0), [Img{plain(), 64.0, 64.0, 255}, Icon{plain(), 16711680}]},
    Divider{plain()},
    ScrollView{Style{Row{}, JEnd{}, ACenter{}, Auto{}, Px{48.0}, 0.0, 4.0, 8.0,
      1052688}, 0.0, [
      Link{plain(), "docs", Focus{7}},
      Input{plain(), "type here", False{}, Focus{8}},
      IconButton{pad(4.0), 65280, Inc{0, 10}},
      Canvas{plain(), 32.0, 32.0, 5}]}]}

def view.k3(r: Array<Ent> & Ent, +c: U32, +on: Bool) -> Array<Ent> & Node:
  (a, e) = r
  (a, tree(c, on, ent.v(e)))

def view.k2(r: Array<Ent> & Ent, +c: U32) -> Array<Ent> & Node:
  (a, e) = r
  view.k3(Array.get(Ent, a, 2), c, ent.on(e))

def view.k1(r: Array<Ent> & Ent) -> Array<Ent> & Node:
  (a, e) = r
  view.k2(Array.get(Ent, a, 1), ent.n(e))

def view(s: Array<Ent>) -> Array<Ent> & Node:
  view.k1(Array.get(Ent, s, 0))

# Frame, events, dispatch
# -----------------------

def frame(r: Array<Ent> & Node) -> Array<Ent> & List<&2, L>:
  (a, n) = r
  (a, place(measure([n]), root_ctx(800.0, 600.0), 0.0))

def apply(m: Maybe<&2, Msg>, s: Array<Ent>) -> Array<Ent>:
  match m:
    case None{}:
      s
    case Some{msg}:
      update(msg, s)

def click(r: Array<Ent> & List<&2, L>, +x: F32, +y: F32) -> Array<Ent>:
  (a, ls) = r
  apply(find_hit(hits(ls, Nil{}), x, y), a)

def run(evs: List<Event>, s: Array<Ent>) -> Array<Ent>:
  match evs:
    case Nil{}:
      s
    case Mouse{+x, +y, b, True{}} <> t:
      run(t, click(frame(view(s)), U32.to_f32(x), U32.to_f32(y)))
    case e <> t:
      run(t, s)

# Report
# ------

def show_r(r: Rect) -> String:
  Rect{x, y, w, h} = r
  "(" ++ F32.show(x) ++ "," ++ F32.show(y) ++ " " ++ F32.show(w) ++ "x"
    ++ F32.show(h) ++ ")"

def show_m(m: Maybe<&2, Msg>) -> String:
  match m:
    case None{}:
      ""
    case Some{Inc{i, by}}:
      " on_click=Inc(" ++ U32.show(i) ++ "," ++ U32.show(by) ++ ")"
    case Some{Dec{i}}:
      " on_click=Dec(" ++ U32.show(i) ++ ")"
    case Some{Reset{i}}:
      " on_click=Reset(" ++ U32.show(i) ++ ")"
    case Some{Toggle{i}}:
      " on_click=Toggle(" ++ U32.show(i) ++ ")"
    case Some{SetLevel{i, v}}:
      " on_click=SetLevel(" ++ U32.show(i) ++ ")"
    case Some{Focus{el}}:
      " on_click=Focus(" ++ U32.show(el) ++ ")"

def show_p(p: Paint) -> String:
  match p:
    case PText{s, size, c}:
      " text=" ++ s
    case PBar{v, c}:
      " bar=" ++ F32.show(v)
    case other:
      ""

def dump(ls: List<&2, L>, +ind: String) -> String:
  match ls:
    case Nil{}:
      ""
    case L{r, p, h, kids} <> t:
      ind ++ show_r(r) ++ show_p(p) ++ show_m(h) ++ "\n"
        ++ dump(kids, ind ++ "  ") ++ dump(t, ind)

def report.k(r: Array<Ent> & List<&2, L>) -> String:
  (a, ls) = r
  dump(ls, "")

def state.k3(r: Array<Ent> & Ent, s: String) -> String:
  (a, e) = r
  s ++ " level=" ++ F32.show(ent.v(e))

def state.k2(r: Array<Ent> & Ent, s: String) -> String:
  (a, e) = r
  state.k3(Array.get(Ent, a, 2), s ++ " check=" ++ Bool.show(ent.on(e)))

def state.k1(r: Array<Ent> & Ent) -> String:
  (a, e) = r
  state.k2(Array.get(Ent, a, 1), "counter=" ++ U32.show(ent.n(e)))

def state(s: Array<Ent>) -> String:
  state.k1(Array.get(Ent, s, 0))

def store0() -> Array<Ent>:
  Array.set(Ent, Array.set(Ent, Array.set(Ent, Array.new(Ent, 2n, Free{}),
    0, Counter{0}), 1, Check{False{}}), 2, Level{0.25})

def show_u(m: Maybe<&2, U32>) -> String:
  match m:
    case None{}:
      "none"
    case Some{v}:
      U32.show(v)

def imap_demo() -> String:
  +m = IMap.put(32n, IMap.put(32n, IMap.put(32n, ITip{}, 0n, 7, 70), 0n, 8,
    80), 0n, 4294967295, 99)
  "imap 7->" ++ show_u(IMap.get(32n, m, 0n, 7)) ++ " 8->"
    ++ show_u(IMap.get(32n, m, 0n, 8)) ++ " max->"
    ++ show_u(IMap.get(32n, m, 0n, 4294967295)) ++ " 9->"
    ++ show_u(IMap.get(32n, m, 0n, 9))

def clicks() -> List<Event>:
  [Mouse{80, 70, 0, True{}}, Mouse{80, 70, 0, False{}},
    Mouse{80, 70, 0, True{}}, Move{300, 300}, Mouse{80, 70, 0, True{}},
    Mouse{25, 70, 0, True{}}, Mouse{720, 270, 0, True{}},
    Mouse{25, 110, 0, True{}}, Mouse{50, 145, 0, True{}},
    Mouse{400, 500, 0, True{}}, Mouse{510, 270, 0, True{}}]

def layout_of(s: Array<Ent>) -> String:
  report.k(frame(view(s)))

def after() -> Array<Ent>:
  run(clicks(), store0())

def final.k(r: Array<Ent> & Array<Ent>) -> String:
  (a, b) = r
  state(a) ++ "\n" ++ layout_of(b)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("before: " ++ state(store0()))
    IO.print("after:  " ++ final.k(Array.clone(Ent, after())))
    IO.print(imap_demo())
