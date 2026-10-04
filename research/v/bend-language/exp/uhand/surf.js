const surf = [];
io_eff(CID(Surface.open_raw), (w, h) => { surf.push([w, h]); return surf.length - 1; });
io_eff(CID(Surface.area_raw), (i) => (surf[i][0] * surf[i][1]) >>> 0);
