static u32 surf_w[16], surf_h[16], surf_n = 0;
Term surface_open_raw_run(Env e, Term* f, IoWork* w) {
  u32 i = surf_n++ & 15; surf_w[i] = (u32)f[0]; surf_h[i] = (u32)f[1];
  return (Term)i;
}
Term surface_area_raw_run(Env e, Term* f, IoWork* w) {
  u32 i = (u32)f[0] & 15;
  return (Term)(surf_w[i] * surf_h[i]);
}
static void __attribute__((constructor)) surf_use(void) {
  io_eff(CID(Surface.open_raw), surface_open_raw_run, 0);
  io_eff(CID(Surface.area_raw), surface_area_raw_run, 0);
}
