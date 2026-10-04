import Base

type Button is Type:
  Button{label: String, on_click: U32 -> U32}

def click_twice(b: Button, s: U32) -> U32:
  Button{label, f} = b
  f(f(s))

def main() -> U32:
  click_twice(Button{"inc", x => (x + 1 : U32)}, 0)
