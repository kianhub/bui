import Base

type Msg is Data:
  Inc{}
  Dec{}

type Node is Data:
  Text{s: String}
  Button{key: String, label: String, on: Msg}
  Column{kids: List<&2, Node>}

def update(m: Msg, n: U32) -> U32:
  match m:
    case Inc{}:
      (n + 1 : U32)
    case Dec{}:
      (n - 1 : U32)

def view(+n: U32) -> Node:
  Column{[Text{"Count: " ++ U32.show(n)}, Button{"inc", "+", Inc{}}, Button{"dec", "-", Dec{}}]}

def fold(ms: List<&2, Msg>, n: U32) -> U32:
  match ms:
    case Nil{}:
      n
    case m <> rest:
      fold(rest, update(m, n))

def main() -> Node:
  view(fold([Inc{}, Inc{}, Inc{}, Dec{}], 10))
