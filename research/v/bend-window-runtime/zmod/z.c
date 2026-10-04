#import <zlib.h>

Term z_version_run(Env e, Term* f, IoWork* w) {
  const char* v = zlibVersion();
  return io_str(e, v, strlen(v));
}

static void __attribute__((constructor)) z_version_use(void) {
  io_eff(CID(Z.version), z_version_run, 0);
}
