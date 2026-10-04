Term gpui_open_run(Env e, Term* f, IoWork* w) {
  return io_done(e, io_hand(42));
}
Term gpui_close_run(Env e, Term* f, IoWork* w) {
  return (Term)(u32)io_hand_v(f[0]);
}
static void __attribute__((constructor)) gpui_use(void) {
  io_eff(CID(Gpui.open), gpui_open_run, 0);
  io_eff(CID(Gpui.close), gpui_close_run, 0);
}
