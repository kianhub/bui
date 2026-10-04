function cbx_arm(w, f, g, b, h) {
  return w;
}

function cbx_take(w) {
  return io_tup(w, "js");
}

io_eff(CID(Cbx.arm), cbx_arm);
io_eff(CID(Cbx.take), cbx_take);
