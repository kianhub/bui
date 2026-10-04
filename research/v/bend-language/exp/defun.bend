import Base

type Msg is Data:
  Inc{by: U32}
  Reset{}

type Button is Data:
  Button{label: String, on_click: Msg}

def update(m: Msg, s: U32) -> U32:
  match m:
    case Inc{by}:
      (s + by : U32)
    case Reset{}:
      0

def click(+b: Button, s: U32) -> U32:
  Button{label, m} = b
  update(m, s)

def main() -> U32:
  +b = {Button{"inc", Inc{5}} : Button}
  click(b, click(b, 0))
