import Base

type Surface is Type:
  Surface{id: U32}

def both(s: Surface) -> Surface & Surface:
  (s, s)

def main() -> U32:
  0
