import Base

type Node is Type:
  Button{label: String, on: U32 -> U32}

def press(n: Node, x: U32) -> U32:
  match n:
    case Button{l, f}:
      f(x)

def twice(n: Node, x: U32) -> U32:
  match n:
    case Button{l, f}:
      f(f(x))

def main() -> U32:
  press(Button{"inc", x => (x + 1 : U32)}, 41)
