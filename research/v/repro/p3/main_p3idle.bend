# Idle-cost probe (repro, item 4). The Scene is built once and never changes.
# IDLE_MODE 0: present it every vsync (P3.present, as p3win does), UI_FRAMES times.
# IDLE_MODE 1: block in P3.wait (up to IDLE_MAX_MS), IDLE_BOUNDED=1 bounds the
#   wait by the runtime's soonest timer, 0 leaves it unbounded (control);
#   present once per wake, IDLE_WAKES times.
# Each loop yields with IO.sleep(0) so spawned tasks run and park their timers.
# In mode 1 a spawned ticker sleeps IDLE_TICK_MS, prints its wake time and
# sends it on a channel; a spawned consumer prints when it receives it.
def P3.draw(qs: Qs, gs: Gs, w: U32, h: U32, mode: U32) -> IO(Qs & Gs):
  import "./p3fx.c"
  import "./p3fx.js"

def P3.present(win: Window, qs: Qs, gs: Gs, mode: U32) -> IO(Window & Qs & Gs):
  import "./p3fx.c"
  import "./p3fx.js"

def P3.dump(k: U32) -> IO(U32):
  import "./p3fx.c"
  import "./p3fx.js"

def P3.wait(win: Window, max_ms: U32, bounded: U32) -> IO(Window & U32):
  import "./p3wait.c"
  import "./p3wait.js"

def idle.end(win: Window, qs: Qs, gs: Gs, a: Array<Glyph>) -> IO(Unit):
  do IO<Unit>:
    Unit <- Window.close(win)
    Unit <- IO.pure(Unit, tile.unit(Qs.sink(qs), Gs.sink(gs)))
    Unit <- IO.print("done")
    finish(a)

# hands the presented Scene on to the continuation
def idle.again(d: Window & Qs & Gs, a: Array<Glyph>, k: Window -> Qs -> Gs -> Array<Glyph> -> IO(Unit)) -> IO(Unit):
  (win, qs, gs) = d
  k(win, qs, gs, a)

# mode 0: present the unchanged Scene every vsync
def idle.present(+n: Nat, win: Window, qs: Qs, gs: Gs, a: Array<Glyph>) -> IO(Unit):
  match n:
    case 0n:
      idle.end(win, qs, gs, a)
    case 1n+p:
      do IO<Unit>:
        d : Window & Qs & Gs <- P3.present(win, qs, gs, 0)
        Unit <- IO.sleep(0)
        idle.again(d, a, w2 => q2 => g2 => a2 => idle.present(p, w2, q2, g2, a2))

# mode 1: the ticker and consumer tasks
def ticker.next(ok: Bool, k: IO(Unit)) -> IO(Unit):
  match ok:
    case True{}:
      k
    case False{}:
      IO.print("tick send failed")

def ticker(+n: Nat, +ms: U32, +c: Chan(U32)) -> IO(Unit):
  match n:
    case 0n:
      Chan.close(U32, c)
    case 1n+p:
      do IO<Unit>:
        Unit <- IO.sleep(ms)
        +t : U32 <- Clock.us()
        Unit <- IO.print("tick us " ++ U32.show(t))
        ok : Bool <- Chan.send(U32, c, t)
        ticker.next(ok, ticker(p, ms, c))

def consumer.got(m: Maybe<&1, U32>, k: IO(Unit)) -> IO(Unit):
  match m:
    case None{}:
      IO.print("consumer done")
    case Some{+t}:
      do IO<Unit>:
        +now : U32 <- Clock.us()
        Unit <- IO.print("recv sent_us " ++ U32.show(t) ++ " seen_us " ++ U32.show(now) ++ " lat_us " ++ U32.show((now - t : U32)))
        k

def consumer(+n: Nat, +c: Chan(U32)) -> IO(Unit):
  match n:
    case 0n:
      IO.print("consumer out of fuel")
    case 1n+p:
      do IO<Unit>:
        m : Maybe<&1, U32> <- Chan.recv(U32, c)
        consumer.got(m, consumer(p, c))

def waiter.woke(r: Window & U32, qs: Qs, gs: Gs, a: Array<Glyph>, +t0: U32, +t1: U32, k: Window -> Qs -> Gs -> Array<Glyph> -> IO(Unit)) -> IO(Unit):
  (win, +ev) = r
  do IO<Unit>:
    Unit <- IO.print("wake us " ++ U32.show(t1) ++ " waited_us " ++ U32.show((t1 - t0 : U32)) ++ " events " ++ U32.show(ev))
    Unit <- IO.sleep(0)
    d : Window & Qs & Gs <- P3.present(win, qs, gs, 0)
    idle.again(d, a, k)

def waiter(+n: Nat, +max_ms: U32, +bounded: U32, win: Window, qs: Qs, gs: Gs, a: Array<Glyph>) -> IO(Unit):
  match n:
    case 0n:
      idle.end(win, qs, gs, a)
    case 1n+p:
      do IO<Unit>:
        Unit <- IO.sleep(0)
        +t0 : U32 <- Clock.us()
        r : Window & U32 <- P3.wait(win, max_ms, bounded)
        +t1 : U32 <- Clock.us()
        waiter.woke(r, qs, gs, a, t0, t1, w2 => q2 => g2 => a2 => waiter(p, max_ms, bounded, w2, q2, g2, a2))

def idle.go(present: Bool, +frames: U32, +wakes: U32, +max_ms: U32, +bounded: U32, +ticks: U32, +tick_ms: U32, win: Window, a: Array<Glyph>, gs: Gs, qs: Qs) -> IO(Unit):
  match present:
    case True{}:
      idle.present(U32.to_nat(frames), win, qs, gs, a)
    case False{}:
      do IO<Unit>:
        +c : Chan(U32) <- Chan.new(U32, 4)
        Unit <- IO.spawn(Unit, ticker(U32.to_nat(ticks), tick_ms, c))
        Unit <- IO.spawn(Unit, consumer(U32.to_nat((ticks + 1 : U32)), c))
        waiter(U32.to_nat(wakes), max_ms, bounded, win, qs, gs, a)

def idle.split(r: Array<Glyph> & Gs, present: Bool, +frames: U32, +wakes: U32, +max_ms: U32, +bounded: U32, +ticks: U32, +tick_ms: U32, win: Window, qs: Qs) -> IO(Unit):
  (a, gs) = r
  idle.go(present, frames, wakes, max_ms, bounded, ticks, tick_ms, win, a, gs, qs)

def idle.go2(shown: Window & Image & List<Event>, +mode: U32, +frames: U32, +wakes: U32, +max_ms: U32, +bounded: U32, +ticks: U32, +tick_ms: U32, +cols: U32, +rows: U32, +w: U32, +h: U32, +g: U32) -> IO(Unit):
  (win, img, evs) = shown
  idle.split(glyphs(g, w, h, atlas()), U32.is_eq(mode, 0), frames, wakes, max_ms, bounded, ticks, tick_ms, win, scene(cols, rows, w, h, frame.ft(0)))

def idle.run(+cfg: Cfg, +mode: U32, +wakes: U32, +max_ms: U32, +bounded: U32, +ticks: U32, +tick_ms: U32) -> IO(Unit):
  Cfg{+cols, +rows, +w, +h, +frames, pace, m, blit, +g, check} = cfg
  do IO<Unit>:
    Unit <- IO.pure(Unit, Image.drop!(Pix{0}))
    win0 : Window <- IO.try(Window, Window.open("p3idle", (w / 2 : U32), (h / 2 : U32)))
    shown : Window & Image & List<Event> <- Window.frame(win0, Pix{0})
    idle.go2(shown, mode, frames, wakes, max_ms, bounded, ticks, tick_ms, cols, rows, w, h, g)

def main() -> IO(Unit):
  do IO<Unit>:
    +cfg : Cfg <- config()
    +mode : U32 <- env("IDLE_MODE", 0)
    +wakes : U32 <- env("IDLE_WAKES", 120)
    +max_ms : U32 <- env("IDLE_MAX_MS", 1000)
    +bounded : U32 <- env("IDLE_BOUNDED", 1)
    +ticks : U32 <- env("IDLE_TICKS", 120)
    +tick_ms : U32 <- env("IDLE_TICK_MS", 250)
    idle.run(cfg, mode, wakes, max_ms, bounded, ticks, tick_ms)
