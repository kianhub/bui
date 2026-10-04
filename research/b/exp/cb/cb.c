Term cb_apply_run(Env e, Term* f, IoWork* w) {
  u64 ap = task_node(e, FID(Clo~apply), TERM_HOLE, 0, 0);
  e.mem[ap]     = f[0];
  e.mem[ap + 1] = f[1];
  return corpus_eval(e.mem, term_tsk(FID(Clo~apply), ap));
}

static void __attribute__((constructor)) cb_apply_use(void) {
  io_eff(CID(Cb.apply), cb_apply_run, 0);
}
