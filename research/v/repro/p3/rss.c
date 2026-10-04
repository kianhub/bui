// Rss.kb: this process's resident set size in KB (mach task info).
#include <mach/mach.h>

Term rss_kb_run(Env e, Term* f, IoWork* w) {
  struct mach_task_basic_info info;
  mach_msg_type_number_t cnt = MACH_TASK_BASIC_INFO_COUNT;
  if (task_info(mach_task_self(), MACH_TASK_BASIC_INFO, (task_info_t)&info, &cnt) != KERN_SUCCESS) {
    return (Term)(u32)0;
  }
  return (Term)(u32)(info.resident_size / 1024);
}

static void __attribute__((constructor)) rss_kb_use(void) {
  io_eff(CID(Rss.kb), rss_kb_run, 0);
}
