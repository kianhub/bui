
# Headless main: Blit stands in for Window.frame.
def run(+cfg: Cfg) -> IO(Unit):
  Cfg{cols, rows, w, h, +frames, pace, mode, blit, g, +check} = cfg
  do IO<Unit>:
    a : Array<Glyph> <- IO.pure(Array<Glyph>, atlas())
    a2 : Array<Glyph> <- run.checked(U32.is_eq(check, 1), cfg, a, a3 => loop(U32.to_nat(frames), cfg, a3))
    finish(a2)

def main() -> IO(Unit):
  do IO<Unit>:
    +cfg : Cfg <- config()
    run(cfg)
