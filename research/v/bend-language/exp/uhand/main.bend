import Base

# A user-defined affine "handle": a Type record over a C-side table index.
type Surface is Type:
  Surface{id: U32}

def Surface.open_raw(w: U32, h: U32) -> IO(U32):
  import "./surf.c"
  import "./surf.js"

def Surface.area_raw(id: U32) -> IO(U32):
  import "./surf.c"
  import "./surf.js"

def Surface.open(w: U32, h: U32) -> IO(Surface):
  do IO<Surface>:
    id : U32 <- Surface.open_raw(w, h)
    return Surface{id}

def Surface.area.k(+id: U32) -> IO(Surface & U32):
  do IO<Surface & U32>:
    a : U32 <- Surface.area_raw(id)
    return (Surface{id}, a)

# Hands the surface back beside the result, like a Base handle effect.
def Surface.area(s: Surface) -> IO(Surface & U32):
  match s:
    case Surface{id}:
      Surface.area.k(id)

def main() -> IO(Unit):
  do IO<Unit>:
    s : Surface <- Surface.open(640, 480)
    r : Surface & U32 <- Surface.area(s)
    IO.print("area " ++ U32.show(Pair.snd(Surface, U32, r)))
