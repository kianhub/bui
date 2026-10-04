function p3_draw(qs, gs, w, h, mode) {
  return io_tup(qs, gs);
}
function p3_dump(k) {
  return 0;
}
io_eff(CID(P3.draw), p3_draw);
io_eff(CID(P3.dump), p3_dump);
function p3_present(win, qs, gs, mode) {
  return io_tup(win, io_tup(qs, gs));
}
io_eff(CID(P3.present), p3_present);
