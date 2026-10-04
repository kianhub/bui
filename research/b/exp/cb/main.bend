# Can C call back into Bend? A foreign effect receives a closure and
# applies it from C by re-entering the evaluator (an undocumented hack
# over the runtime's internals: io_step's own Clo~apply + corpus_eval).
import Base

def Cb.apply(f: U32 -> U32, x: U32) -> IO(U32):
  import "./cb.c"
  import "./cb.js"

def main() -> IO(Unit):
  do IO<Unit>:
    k : U32 <- IO.pure(U32, 1000)
    y : U32 <- Cb.apply(x => (x * 2 + k : U32), 21)
    IO.print("callback result: " ++ U32.show(y))
