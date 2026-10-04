import Base

def view(n: U32) -> U32 & Image:
  +m = n
  (m, Pix{65280})

def stop(done: Bool, +n: U32) -> IO(Maybe<U32>):
  match done:
    case True{}:
      IO.pure(Maybe<U32>, None{})
    case False{}:
      IO.pure(Maybe<U32>, Some{U32.inc(n)})

def tick(events: List<Event>, n: U32) -> IO(Maybe<U32>):
  +m = n
  stop((m >= 3 : U32), m)

def main() -> IO(Unit):
  App.run(~U32, ~App{view, tick}, "app", 64, 64, 0)
