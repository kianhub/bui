
# Frame loop
# ----------

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

type HR is Data:
  HR{sc: Scene, c: U32, nq: U32, ns: U32}

def hit.k(sc: Scene, +px: F32, +py: F32, +c: U32) -> HR:
  Scene{qs, ss, hs, +nq, +ns} = sc
  HR{Scene{qs, ss, Nil{}, nq, ns}, apply(find_hit(hs, px, py), c), nq, ns}

def empty() -> Scene:
  Scene{QNil{}, SpNil{}, Nil{}, 0, 0}

# the whole core in one expression (for the bang variant)
def core.all(+nrows: U32, +c: U32, +scroll: F32, +px: F32, +py: F32) -> HR:
  hit.k(emit(layout(view(nrows, c, scroll), 1920.0, 1200.0), empty()), px, py, c)

def lay(bang: Bool, n: Node) -> List<&2, L>:
  match bang:
    case False{}:
      layout(n, 1920.0, 1200.0)
    case True{}:
      layout!(n, 1920.0, 1200.0)

def say.go(u: Unit, +c: U32, +nq: U32, +ns: U32, +i: U32, +t0: U32, +t1: U32, +t2: U32, +t3: U32, +t4: U32, +t5: U32, k: U32 -> IO(Unit)) -> IO(Unit):
  match u:
    case Unit{}:
      do IO<Unit>:
        IO.print("f " ++ U32.show(i) ++ " view_us " ++ U32.show((t1 - t0 : U32)) ++ " layout_us " ++ U32.show((t2 - t1 : U32))
          ++ " paint_us " ++ U32.show((t3 - t2 : U32)) ++ " hit_us " ++ U32.show((t4 - t3 : U32))
          ++ " core_us " ++ U32.show((t4 - t0 : U32)) ++ " nq " ++ U32.show(nq) ++ " ns " ++ U32.show(ns) ++ " c " ++ U32.show(c))
        k(c)

# staged frame: view | layout (measure + wrap + place) | paint (scene + hitboxes) | hit + dispatch

def say.k(r: HR, +i: U32, +t0: U32, +t1: U32, +t2: U32, +t3: U32, +t4: U32, +t5: U32, k: U32 -> IO(Unit)) -> IO(Unit):
  HR{sc, +c, +nq, +ns} = r
  say.go(scene.sink(sc), c, nq, ns, i, t0, t1, t2, t3, t4, t5, k)

def frame.staged(+nrows: U32, +c: U32, +i: U32, bang: Bool, k: U32 -> IO(Unit)) -> IO(Unit):
  +scroll = U32.to_f32((i % 400 : U32))
  do IO<Unit>:
    +t0 : U32 <- Clock.us()
    n : Node <- IO.pure(Node, view(nrows, c, scroll))
    +t1 : U32 <- Clock.us()
    ls : List<&2, L> <- IO.pure(List<&2, L>, lay(bang, n))
    +t2 : U32 <- Clock.us()
    sc : Scene <- IO.pure(Scene, emit(ls, empty()))
    +t3 : U32 <- Clock.us()
    r : HR <- IO.pure(HR, hit.k(sc, 1880.0, 30.0, c))
    +t4 : U32 <- Clock.us()
    say.k(r, i, t0, t1, t2, t3, t4, t4, k)

# one-expression frame, optionally banged as a whole
def core.one(bang: Bool, +nrows: U32, +c: U32, +scroll: F32) -> HR:
  match bang:
    case False{}:
      core.all(nrows, c, scroll, 1880.0, 30.0)
    case True{}:
      core.all!(nrows, c, scroll, 1880.0, 30.0)


def frame.one(+nrows: U32, +c: U32, +i: U32, bang: Bool, k: U32 -> IO(Unit)) -> IO(Unit):
  +scroll = U32.to_f32((i % 400 : U32))
  do IO<Unit>:
    +t0 : U32 <- Clock.us()
    r : HR <- IO.pure(HR, core.one(bang, nrows, c, scroll))
    +t4 : U32 <- Clock.us()
    say.k(r, i, t0, t0, t0, t0, t4, t4, k)

def frame(one: Bool, +nrows: U32, +c: U32, +i: U32, bang: Bool, k: U32 -> IO(Unit)) -> IO(Unit):
  match one:
    case False{}:
      frame.staged(nrows, c, i, bang, k)
    case True{}:
      frame.one(nrows, c, i, bang, k)

def loop(+n: Nat, +nrows: U32, +frames: U32, +one: U32, +bang: U32, c: U32) -> IO(Unit):
  match n:
    case 0n:
      IO.print("done c " ++ U32.show(c))
    case 1n+p:
      +i = (frames - U32.from_nat(p) - 1 : U32)
      frame(U32.is_eq(one, 1), nrows, c, i, U32.is_eq(bang, 1), c2 => loop(p, nrows, frames, one, bang, c2))

def main() -> IO(Unit):
  do IO<Unit>:
    +nrows : U32 <- env("UI_ROWS", 500)
    +frames : U32 <- env("UI_FRAMES", 110)
    +one : U32 <- env("UI_ONE", 0)
    +bang : U32 <- env("UI_BANG", 0)
    IO.print("elements " ++ U32.show(count([view(nrows, 0, 0.0)], 0)) ++ " rows " ++ U32.show(nrows))
    loop(U32.to_nat(frames), nrows, frames, one, bang, 0)
