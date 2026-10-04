#import "research/v/bend-window-runtime/demolib/demo.h"

Term demo_answer_run(Env e, Term* f, IoWork* w) {
  return (Term)demo_answer((u32)f[0]);
}

static void __attribute__((constructor)) demo_answer_use(void) {
  io_eff(CID(Demo.answer), demo_answer_run, 0);
}
