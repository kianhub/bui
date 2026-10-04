function syn_arm(w, st, step) {
  return w;
}

function syn_take(w) {
  return io_tup(w, io_tup("", "js"));
}

io_eff(CID(Syn.arm), syn_arm);
io_eff(CID(Syn.take), syn_take);
