function gpui_open() { return io_done(42); }
function gpui_close(g) { return g; }
io_eff(CID(Gpui.open), gpui_open);
io_eff(CID(Gpui.close), gpui_close);
