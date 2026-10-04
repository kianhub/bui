// Clock.us: microseconds from the runtime's monotonic tick, as a U32.
Term clock_us_run(Env e, Term* f, IoWork* w) {
  return (Term)(u32)(io_tick() / 1000ull);
}

static void __attribute__((constructor)) clock_us_use(void) {
  io_eff(CID(Clock.us), clock_us_run, 0);
}
