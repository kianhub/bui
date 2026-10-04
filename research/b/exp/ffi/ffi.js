// FFI probes (JS lane stubs)

function text_width(text, size) {
  return 0;
}

function px_sum(a) {
  let s = 0;
  for (const x of a) {
    s = (s + x) >>> 0;
  }
  return io_tup(a, s);
}

function nop_call(x) {
  return (x + 1) >>> 0;
}

io_eff(CID(Text.width), text_width);
io_eff(CID(Px.sum), px_sum);
io_eff(CID(Nop.call), nop_call);
