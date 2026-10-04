import Base

# A Type (affine) node may hold a closure; calling it once is fine.
type Node is Type:
  Btn{label: String, on_click: U32 -> U32}
  Col{kids: List<&1, Node>}

def click_first(n: Node, s: U32) -> U32:
  match n:
    case Btn{label, f}:
      f(s)
    case Col{kids}:
      s

def main() -> U32:
  k : U32 = 7
  click_first(Btn{"inc", x => (x + k : U32)}, 35)
