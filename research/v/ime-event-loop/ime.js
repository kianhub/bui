function ime_attach(w) {
  return w;
}

function ime_push(w, text, caret, mark) {
  return w;
}

function ime_drain(w) {
  return io_tup(w, { $: "Nil" });
}

function ime_test(w, step) {
  return w;
}

io_eff(CID(Ime.attach), ime_attach);
io_eff(CID(Ime.push), ime_push);
io_eff(CID(Ime.drain), ime_drain);
io_eff(CID(Ime.test), ime_test);
