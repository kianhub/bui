function p3_wait(win, max_ms, bounded) {
  return io_tup(win, 0);
}
io_eff(CID(P3.wait), p3_wait);
