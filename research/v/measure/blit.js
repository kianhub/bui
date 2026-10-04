function blit_run(image, w, h, k) {
  return image;
}
function blit_pick(x, y) {
  return 0;
}
function blit_sum() {
  return 0;
}

io_eff(CID(Blit.run), blit_run);
io_eff(CID(Blit.pick), blit_pick);
io_eff(CID(Blit.sum), blit_sum);
