function word_to_u32(w) {
  let x = 0;
  for (let i = 0; w.$ === "WCon"; i++) {
    x |= Number(w.head) << i;
    w = w.tail;
  }
  return x >>> 0;
}

function u32_to_word(x) {
  let w = {$: "WNil"};
  for (let i = 31; i >= 0; i--) {
    w = {$: "WCon", head: ((x >>> i) & 1) === 1, tail: w};
  }
  return w;
}

function cmp_new(a, b) {
  return {$: a < b ? "LT"
    : a === b ? "EQ" : "GT"};
}

function nat_divmod(a, b) {
  return b === 0 ? {$: "Tuple", fst: 0, snd: a}
    : {$: "Tuple", fst: Math.trunc(a / b), snd: a % b};
}

function nat_chk(n) {
  if (n > 281474976710655) {
    throw "bend: a Nat past the largest immediate 2^48-1";
  }
  return n;
}

function nat_host(n) {
  const int = typeof n === "bigint" || Number.isInteger(n);
  if (int && n >= 0 && n <= 2 ** 53) {
    return Number(n);
  }
  return { [Symbol.toPrimitive]() { throw "bend: a Nat past the largest immediate 2^48-1"; } };
}

function f32_show(x) {
  if (x !== x) {
    return "nan";
  }
  if (!Number.isFinite(x) || Object.is(x, -0)) {
    return x < 0 ? "-inf"
      : x === 0 ? "-0" : "inf";
  }
  let s = "x";
  for (let p = 1; p <= 9 && f32_round(s) !== x; p += 1) {
    s = String(Number(x.toExponential(p - 1)));
  }
  return s;
}

function f32_bits(x) {
  return new Uint32Array(new Float32Array([x]).buffer)[0];
}

function f32_from_bits(u) {
  return new Float32Array(new Uint32Array([u]).buffer)[0];
}

function f32_read(s) {
  const re = /^\s*[+-]?((\d+\.?\d*|\.\d+)(e[+-]?\d+)?|inf(inity)?|nan)$/i;
  const v = f32_round(s.replace(/inf\w*/i, "Infinity"));
  return re.test(s) ? {$: "Some", value: v} : {$: "None"};
}

const f32_round = function f32_round(s) {
  const d = Number(s), a = Math.abs(d), f = Math.fround(a), g = 2 * a - Math.min(f, 340282366920938500000000000000000000000);
  if (g === f || Math.fround(g) !== g || g === 1 / 0)
    return Math.sign(d) * f;
  let k = 0;
  while (a * 2 ** k % 1 !== 0)
    k += 1;
  const [, i, r, e] = /(\d*)\.?(\d*)(?:e([+-]?\d+))?$/i.exec(s), n = Number(e ?? 0) - r.length, x = BigInt(i + r) * 2n ** BigInt(k) * 10n ** BigInt(Math.max(n, 0)), y = BigInt(a * 2 ** k) * 10n ** BigInt(Math.max(-n, 0));
  return Math.sign(d) * (x === y || x > y !== g > f ? f : g);
};

function char_new(code) {
  if (code > 0x10FFFF || (code >= 0xD800 && code <= 0xDFFF)) {
    throw "bend: " + code + " is not a Unicode scalar value";
  }
  return String.fromCodePoint(code);
}

// Array
// =====

function array_new(d, v) {
  if (d > 31) {
    throw "bend: an array past the deepest block class 31";
  }
  return Array(2 ** d).fill(v);
}

function array_node(a, b) {
  if (a.length !== b.length) {
    throw "bend: runtime fail-stop";
  }
  return a.concat(b);
}

function array_rmw(a, i, f) {
  const at = i % a.length;
  const old = a[at];
  a[at] = f(old);
  return {$: "Tuple", fst: a, snd: old};
}

// Run
// ===

function run_tail(f, x) {
  return {$: "$JMP", f: f.j?.f === f ? f.j : f, x: [x]};
}

function run_clo(j) {
  const f = (x) => run_loop(j(x));
  f.j = j;
  j.f = f;
  return f;
}

function run_loop(r) {
  while (r !== null && typeof r === "object" && r.$ === "$JMP") {
    r = r.f(...r.x);
  }
  return r;
}

function run_lib(f, n) {
  return (...a) => a.length < n ? run_lib((...b) => f(...a, ...b), n - a.length)
    : f(...a);
}

// Effect
// ======

const $0eff = Object.create(null);

function io_eff(k, run, need) {
  if (k in $0eff) {
    throw new Error("bend: two effects register " + k);
  }
  $0eff[k] = { run, need };
}
(() => {
function clock_us() {
  return Math.floor(performance.now() * 1000) >>> 0;
}

io_eff("Clock.us", clock_us);

})();

(() => {
// IO
// ==

function io_print(text) {
  io_out(1, io_bytes(text + "\n"));
  return { $: "Unit" };
}

io_eff("IO.print", io_print);

})();

for (const k of ["Clock.us","IO.print"]) {
  if (!(k in $0eff)) {
    throw new Error("bend: no effect registers " + k);
  }
}

// Program
// =======

function $main$() {
  return run_clo((_x_0) => {
  return $IO$bind$(($loop$(false, 40)), run_clo((_x_1) => {
  return run_clo((_x_2) => {
  return $IO$bind$(($loop$(true, 40)), run_clo((_x_3) => {
  return run_clo((_x_4) => {
  return $IO$bind$(($check$(false)), run_clo((_x_5) => {
  return $check$(true);
}), _x_4);
});
}), _x_2);
});
}), _x_0);
});
}

function $IO$bind$(_m_0, _f_0, _k_0) {
  return run_tail(_m_0, run_clo((_x_0) => {
  return run_tail(_f_0(_x_0), _k_0);
}));
}

function $loop$(_fl_0, _n_0) {
  if (_n_0 === 0) {
    return run_clo((_x_0) => {
  return $IO$pure$({$: "Unit"}, _x_0);
});
  } else {
    const _p_0 = (_n_0 - 1);
    return run_clo((_x_1) => {
  return $IO$bind$((_x_2) => $Clock$us$(_x_2), run_clo((_x_3) => {
  return run_clo((_x_4) => {
  return $IO$bind$(run_clo((_x_5) => {
  return $IO$pure$(($frame$(($F32$from_nat$(_p_0)), _fl_0)), _x_5);
}), run_clo((_x_6) => {
  return run_clo((_x_7) => {
  return $IO$bind$((_x_8) => $Clock$us$(_x_8), run_clo((_x_9) => {
  return run_clo((_x_10) => {
  return $IO$bind$(run_clo((_x_11) => {
  return $IO$pure$(($Image$drop$(_x_6)), _x_11);
}), run_clo((_x_12) => {
  return run_clo((_x_13) => {
  return $IO$bind$((_x_14) => $Clock$us$(_x_14), run_clo((_x_15) => {
  return run_clo((_x_16) => {
  const _x_17 = ($U32$show$(((_x_15 - _x_9) >>> 0)));
  const _x_18 = ($U32$show$(((_x_9 - _x_3) >>> 0)));
  const _x_19 = (" drop_us " + _x_17);
  const _x_20 = (_x_18 + _x_19);
  const _x_21 = ($Bool$show$(_fl_0));
  const _x_22 = (" render_us " + _x_20);
  const _x_23 = (_x_21 + _x_22);
  return $IO$bind$((_x_24) => $IO$print$(("fl " + _x_23), _x_24), run_clo((_x_25) => {
  return $loop$(_fl_0, _p_0);
}), _x_16);
});
}), _x_13);
});
}), _x_10);
});
}), _x_7);
});
}), _x_4);
});
}), _x_1);
});
  }
}

function $check$(_fl_0) {
  return run_clo((_x_0) => {
  return $IO$bind$(run_clo((_x_1) => {
  return $IO$pure$(($frame$(7, _fl_0)), _x_1);
}), run_clo((_x_2) => {
  const _x_3 = ($U32$show$(($leaves$(_x_2))));
  const _x_4 = ($U32$show$(($isum$(_x_2, 2048))));
  const _x_5 = (" leaves " + _x_3);
  const _x_6 = (_x_4 + _x_5);
  const _x_7 = ($Bool$show$(_fl_0));
  const _x_8 = (" isum " + _x_6);
  const _x_9 = (_x_7 + _x_8);
  return (_x_10) => $IO$print$(("fl " + _x_9), _x_10);
}), _x_0);
});
}

function $IO$pure$(_x_0, _k_0) {
  return run_tail(_k_0, _x_0);
}

function $Clock$us$(_k_0) {
  return { $: "$FFI", run: $0eff["Clock.us"].run, need: $0eff["Clock.us"].need, args: [], kont: (_k_0) };
}
function $frame$(_ft_0, _fl_0) {
  return $node$(7, true, ($isflat$(_fl_0, 2048, 0, 0, _ft_0)), 0, 0, _ft_0, _fl_0);
}

function $F32$from_nat$(_n_0) {
  const _x_0 = (_n_0 >>> 0);
  return Math.fround(_x_0);
}

function $Image$drop$(_img_0) {
  return $Image$free$(7, _img_0);
}

function $IO$print$(_text_0, _k_0) {
  return { $: "$FFI", run: $0eff["IO.print"].run, need: $0eff["IO.print"].need, args: [(_text_0)], kont: (_k_0) };
}
function $Bool$show$(_b_0) {
  if (!_b_0) {
    return "False";
  } else {
    return "True";
  }
}

function $U32$show$(_a_0) {
  const _b_0 = _a_0;
  return $U32$show$if$(_b_0, (_b_0 === 0));
}

function $isum$(_img_0, _s_0) {
  if (_img_0.$ === "Pix") {
    const _c_0 = _img_0["color"];
    const _x_0 = (Math.imul(_c_0, _s_0) >>> 0);
    return (Math.imul(_x_0, _s_0) >>> 0);
  } else {
    const _a_0 = _img_0["tl"];
    const _b_0 = _img_0["tr"];
    const _c_1 = _img_0["bl"];
    const _d_0 = _img_0["br"];
    const _h_0 = ((_s_0 >>> 1) >>> 0);
    const _x_1 = ($isum$(_a_0, _h_0));
    const _x_2 = ($isum$(_b_0, _h_0));
    const _x_3 = ((_x_1 + _x_2) >>> 0);
    const _x_4 = ($isum$(_c_1, _h_0));
    const _x_5 = ((_x_3 + _x_4) >>> 0);
    const _x_6 = ($isum$(_d_0, _h_0));
    return ((_x_5 + _x_6) >>> 0);
  }
}

function $leaves$(_img_0) {
  if (_img_0.$ === "Pix") {
    return 1;
  } else {
    const _a_0 = _img_0["tl"];
    const _b_0 = _img_0["tr"];
    const _c_1 = _img_0["bl"];
    const _d_0 = _img_0["br"];
    const _x_0 = ($leaves$(_a_0));
    const _x_1 = ($leaves$(_b_0));
    const _x_2 = ((_x_0 + _x_1) >>> 0);
    const _x_3 = ($leaves$(_c_1));
    const _x_4 = ((_x_2 + _x_3) >>> 0);
    const _x_5 = ($leaves$(_d_0));
    return ((_x_4 + _x_5) >>> 0);
  }
}

function $node$(_k_0, _on_0, _flat_0, _x_0, _y_0, _ft_0, _fl_0) {
  if (_k_0 === 0) {
    if (!_on_0) {
      return {$: "Pix", "color": 0};
    } else {
      if (_flat_0) {
        return {$: "Pix", "color": ($shade$(_x_0, _y_0, _ft_0))};
      } else {
        return $t16$(_x_0, _y_0, _ft_0);
      }
    }
  } else {
    const _e_0 = (_k_0 - 1);
    if (!_on_0) {
      return {$: "Pix", "color": 0};
    } else {
      if (_flat_0) {
        return {$: "Pix", "color": ($shade$(_x_0, _y_0, _ft_0))};
      } else {
        const _s_0 = (_e_0 >= 32 ? 0 : (16 << _e_0) >>> 0);
        const _x1_0 = ((_x_0 + _s_0) >>> 0);
        const _y1_0 = ((_y_0 + _s_0) >>> 0);
        const _a_0 = ($node$(_e_0, true, ($isflat$(_fl_0, _s_0, _x_0, _y_0, _ft_0)), _x_0, _y_0, _ft_0, _fl_0));
        const _b_0 = ($node$(_e_0, (_x1_0 < 1920), ($isflat$(_fl_0, _s_0, _x1_0, _y_0, _ft_0)), _x1_0, _y_0, _ft_0, _fl_0));
        const _c_0 = ($node$(_e_0, (_y1_0 < 1080), ($isflat$(_fl_0, _s_0, _x_0, _y1_0, _ft_0)), _x_0, _y1_0, _ft_0, _fl_0));
        const _d_0 = ($node$(_e_0, ($Bool$and$((_x1_0 < 1920), (_y1_0 < 1080))), ($isflat$(_fl_0, _s_0, _x1_0, _y1_0, _ft_0)), _x1_0, _y1_0, _ft_0, _fl_0));
        return {$: "Qua", "tl": _a_0, "tr": _b_0, "bl": _c_0, "br": _d_0};
      }
    }
  }
}

function $isflat$(_fl_0, _s_0, _x_0, _y_0, _ft_0) {
  if (!_fl_0) {
    return false;
  } else {
    const _x_1 = Math.fround(_s_0);
    const _h_0 = Math.fround(_x_1 * 0.5);
    const _x_2 = Math.fround(_x_0);
    const _cx_0 = Math.fround(_x_2 + _h_0);
    const _x_3 = Math.fround(_y_0);
    const _cy_0 = Math.fround(_x_3 + _h_0);
    const _x_4 = Math.fround(_h_0 * 1.4142999649047852);
    const _m_0 = Math.fround(_x_4 + 0.5);
    return $Bool$and$(($Bool$and$(($Bool$and$(($far$(($d1$(_cx_0, _cy_0, _ft_0)), _m_0)), ($far$(($d2$(_cx_0, _cy_0, _ft_0)), _m_0)))), ($far$(($d3$(_cx_0, _cy_0, _ft_0)), _m_0)))), ($far$(($d4$(_cx_0, _cy_0, _ft_0)), _m_0)));
  }
}

function $Image$free$(_k_0, _img_0) {
  if (_k_0 === 0) {
    return $Image$sink$(_img_0);
  } else {
    const _e_0 = (_k_0 - 1);
    if (_img_0.$ === "Pix") {
      return {$: "Unit"};
    } else {
      const _tl_0 = _img_0["tl"];
      const _tr_0 = _img_0["tr"];
      const _bl_0 = _img_0["bl"];
      const _br_0 = _img_0["br"];
      const _a_0 = ($Image$free$(_e_0, _tl_0));
      const _b_0 = ($Image$free$(_e_0, _tr_0));
      const _c_1 = ($Image$free$(_e_0, _bl_0));
      const _d_0 = ($Image$free$(_e_0, _br_0));
      return $Image$drop$join$(_a_0, _b_0, _c_1, _d_0);
    }
  }
}

function $U32$show$if$(_a_0, _z_0) {
  if (_z_0) {
    return "0";
  } else {
    return $U32$show$go$(10, _a_0, "");
  }
}

function $shade$(_x_0, _y_0, _ft_0) {
  const _x_1 = Math.fround(_x_0);
  const _px_0 = Math.fround(_x_1 + 0.5);
  const _x_2 = Math.fround(_y_0);
  const _py_0 = Math.fround(_x_2 + 0.5);
  const _a1_0 = ($cov$(($d1$(_px_0, _py_0, _ft_0))));
  const _a2_0 = ($cov$(($d2$(_px_0, _py_0, _ft_0))));
  const _a3_0 = ($cov$(($d3$(_px_0, _py_0, _ft_0))));
  const _a4_0 = ($cov$(($d4$(_px_0, _py_0, _ft_0))));
  const _r_0 = ($over$(($over$(($over$(($over$(0.10000000149011612, 0.8999999761581421, _a1_0)), 0.20000000298023224, _a2_0)), 0.949999988079071, _a3_0)), 0.4000000059604645, _a4_0));
  const _g_0 = ($over$(($over$(($over$(($over$(0.10999999940395355, 0.8999999761581421, _a1_0)), 0.5, _a2_0)), 0.6000000238418579, _a3_0)), 0.800000011920929, _a4_0));
  const _b_0 = ($over$(($over$(($over$(($over$(0.12999999523162842, 0.9200000166893005, _a1_0)), 0.8999999761581421, _a2_0)), 0.20000000298023224, _a3_0)), 0.4000000059604645, _a4_0));
  return $pack$(_r_0, _g_0, _b_0);
}

function $t16$(_x_0, _y_0, _ft_0) {
  const _x1_0 = ((_x_0 + 8) >>> 0);
  const _y1_0 = ((_y_0 + 8) >>> 0);
  return {$: "Qua", "tl": ($t8$(_x_0, _y_0, _ft_0)), "tr": ($t8$(_x1_0, _y_0, _ft_0)), "bl": ($t8$(_x_0, _y1_0, _ft_0)), "br": ($t8$(_x1_0, _y1_0, _ft_0))};
}

function $Bool$and$(_a_0, _b_0) {
  if (!_a_0) {
    return false;
  } else {
    return _b_0;
  }
}

function $far$(_d_0, _m_0) {
  const _x_0 = Math.fround(Math.abs(_d_0));
  return (_x_0 >= _m_0);
}

function $d1$(_px_0, _py_0, _ft_0) {
  return $sdf$(_px_0, _py_0, Math.fround(480 + _ft_0), 300, 400, 220, 16);
}

function $d2$(_px_0, _py_0, _ft_0) {
  return $sdf$(_px_0, _py_0, 1300, Math.fround(500 + _ft_0), 360, 300, 24);
}

function $d3$(_px_0, _py_0, _ft_0) {
  return $sdf$(_px_0, _py_0, 960, 900, Math.fround(800 + _ft_0), 80, 40);
}

function $d4$(_px_0, _py_0, _ft_0) {
  return $sdf$(_px_0, _py_0, Math.fround(700 - _ft_0), 640, 120, 120, 60);
}

function $Image$sink$(_img_0) {
  return {$: "Unit"};
}

function $Image$drop$join$(_a_0, _b_0, _c_0, _d_0) {
  return {$: "Unit"};
}

function $U32$show$go$($0, $1, $2, $3) {
  let $pc = 0;
  for (;;) switch ($pc) {
    case 0: {
      const _f_0 = $0;
      const _n_0 = $1;
      const _acc_0 = $2;
      if (_f_0 === 0) {
        return _acc_0;
      } else {
        const _g_0 = (_f_0 - 1);
        $0 = _g_0;
        $1 = _acc_0;
        $2 = _n_0;
        $3 = (_n_0 === 0);
        $pc = 1; continue;
      }
    }
    case 1: {
      const _g_0 = $0;
      const _acc_0 = $1;
      const _n_0 = $2;
      const _z_0 = $3;
      if (_z_0) {
        return _acc_0;
      } else {
        const _x_0 = (10 === 0 ? _n_0 : _n_0 % 10);
        $0 = _g_0;
        $1 = (10 === 0 ? 0 : (_n_0 / 10) >>> 0);
        $2 = (char_new(((48 + _x_0) >>> 0)) + _acc_0);
        $pc = 0; continue;
      }
    }
  }
}

function $cov$(_d_0) {
  return $sat$(Math.fround(0.5 - _d_0));
}

function $over$(_dst_0, _src_0, _a_0) {
  const _x_0 = Math.fround(_src_0 - _dst_0);
  const _x_1 = Math.fround(_x_0 * _a_0);
  return Math.fround(_dst_0 + _x_1);
}

function $pack$(_r_0, _g_0, _b_0) {
  const _x_0 = ($sat$(_r_0));
  const _x_1 = Math.fround(255 * _x_0);
  const _x_2 = (_x_1 >= 1 && _x_1 < 4294967296 ? Math.floor(_x_1) : 0);
  const _x_3 = ($sat$(_g_0));
  const _x_4 = Math.fround(255 * _x_3);
  const _x_5 = (_x_4 >= 1 && _x_4 < 4294967296 ? Math.floor(_x_4) : 0);
  const _x_6 = (16 >= 32 ? 0 : (_x_2 << 16) >>> 0);
  const _x_7 = (8 >= 32 ? 0 : (_x_5 << 8) >>> 0);
  const _x_8 = ($sat$(_b_0));
  const _x_9 = Math.fround(255 * _x_8);
  const _x_10 = ((_x_6 | _x_7) >>> 0);
  const _x_11 = (_x_9 >= 1 && _x_9 < 4294967296 ? Math.floor(_x_9) : 0);
  return ((_x_10 | _x_11) >>> 0);
}

function $t8$(_x_0, _y_0, _ft_0) {
  const _x1_0 = ((_x_0 + 4) >>> 0);
  const _y1_0 = ((_y_0 + 4) >>> 0);
  return {$: "Qua", "tl": ($t4$(_x_0, _y_0, _ft_0)), "tr": ($t4$(_x1_0, _y_0, _ft_0)), "bl": ($t4$(_x_0, _y1_0, _ft_0)), "br": ($t4$(_x1_0, _y1_0, _ft_0))};
}

function $sdf$(_px_0, _py_0, _cx_0, _cy_0, _hw_0, _hh_0, _r_0) {
  const _x_0 = Math.fround(_px_0 - _cx_0);
  const _x_1 = Math.fround(Math.abs(_x_0));
  const _x_2 = Math.fround(_x_1 - _hw_0);
  const _qx_0 = Math.fround(_x_2 + _r_0);
  const _x_3 = Math.fround(_py_0 - _cy_0);
  const _x_4 = Math.fround(Math.abs(_x_3));
  const _x_5 = Math.fround(_x_4 - _hh_0);
  const _qy_0 = Math.fround(_x_5 + _r_0);
  const _ox_0 = ($fmax$(_qx_0, 0));
  const _oy_0 = ($fmax$(_qy_0, 0));
  const _x_6 = Math.fround(_ox_0 * _ox_0);
  const _x_7 = Math.fround(_oy_0 * _oy_0);
  const _x_8 = Math.fround(_x_6 + _x_7);
  const _x_9 = Math.fround(Math.sqrt(_x_8));
  const _x_10 = ($fmin$(($fmax$(_qx_0, _qy_0)), 0));
  const _x_11 = Math.fround(_x_9 + _x_10);
  return Math.fround(_x_11 - _r_0);
}

function $U32$show$fin$($0, $1, $2, $3) {
  let $pc = 1;
  for (;;) switch ($pc) {
    case 0: {
      const _f_0 = $0;
      const _n_0 = $1;
      const _acc_0 = $2;
      if (_f_0 === 0) {
        return _acc_0;
      } else {
        const _g_0 = (_f_0 - 1);
        $0 = _g_0;
        $1 = _acc_0;
        $2 = _n_0;
        $3 = (_n_0 === 0);
        $pc = 1; continue;
      }
    }
    case 1: {
      const _g_0 = $0;
      const _acc_0 = $1;
      const _n_0 = $2;
      const _z_0 = $3;
      if (_z_0) {
        return _acc_0;
      } else {
        const _x_0 = (10 === 0 ? _n_0 : _n_0 % 10);
        $0 = _g_0;
        $1 = (10 === 0 ? 0 : (_n_0 / 10) >>> 0);
        $2 = (char_new(((48 + _x_0) >>> 0)) + _acc_0);
        $pc = 0; continue;
      }
    }
  }
}

function $sat$(_x_0) {
  return $fmin$(1, ($fmax$(0, _x_0)));
}

function $t4$(_x_0, _y_0, _ft_0) {
  const _x1_0 = ((_x_0 + 2) >>> 0);
  const _y1_0 = ((_y_0 + 2) >>> 0);
  return {$: "Qua", "tl": ($blk$(_x_0, _y_0, _ft_0)), "tr": ($blk$(_x1_0, _y_0, _ft_0)), "bl": ($blk$(_x_0, _y1_0, _ft_0)), "br": ($blk$(_x1_0, _y1_0, _ft_0))};
}

function $fmax$(_a_0, _b_0) {
  return $pick$((_a_0 < _b_0), _b_0, _a_0);
}

function $fmin$(_a_0, _b_0) {
  return $pick$((_a_0 < _b_0), _a_0, _b_0);
}

function $blk$(_x_0, _y_0, _ft_0) {
  const _x1_0 = ((_x_0 + 1) >>> 0);
  const _y1_0 = ((_y_0 + 1) >>> 0);
  const _c0_0 = ($shade$(_x_0, _y_0, _ft_0));
  const _c1_0 = ($shade$(_x1_0, _y_0, _ft_0));
  const _c2_0 = ($shade$(_x_0, _y1_0, _ft_0));
  const _c3_0 = ($shade$(_x1_0, _y1_0, _ft_0));
  return $blk$mk$(($Bool$and$(($Bool$and$((_c0_0 === _c1_0), (_c1_0 === _c2_0))), (_c2_0 === _c3_0))), _c0_0, _c1_0, _c2_0, _c3_0);
}

function $pick$(_c_0, _a_0, _b_0) {
  if (_c_0) {
    return _a_0;
  } else {
    return _b_0;
  }
}

function $blk$mk$(_same_0, _c0_0, _c1_0, _c2_0, _c3_0) {
  if (_same_0) {
    return {$: "Pix", "color": _c0_0};
  } else {
    return {$: "Qua", "tl": {$: "Pix", "color": _c0_0}, "tr": {$: "Pix", "color": _c1_0}, "bl": {$: "Pix", "color": _c2_0}, "br": {$: "Pix", "color": _c3_0}};
  }
}

// Cli
// ===

let cli_args = [];

function cli(argv) {
  cli_args.push(argv[0]);
  for (let i = 1; i < argv.length; i += 1) {
    if (argv[i] === "--") {
      cli_args.push(...argv.slice(i + 1));
      break;
    } else if (argv[i] === "--bend-help") {
      io_out(1, io_bytes("usage: " + argv[0] + "\n"));
      process.exit(0);
    } else if (argv[i] === "--threads" || argv[i] === "--gpu") {
      i += 1;
    } else {
      cli_args.push(argv[i]);
    }
  }
}

// Show
// ====

// show_val prints a pure main's value as term_show does (see show_main);
// chain is the bracket it continues, or 0. show_chr escapes as char_show.

function show_chr(c, q) {
  const k = { 10: "n", 9: "t", 13: "r", 0: "0", 92: "\\" }[c]
    ?? (c === q.codePointAt(0) ? q : null);
  return k !== null ? "\\" + k : c < 32 || c === 127
    || (c >= 0xD800 && c <= 0xDFFF) || c > 0x10FFFF
    ? "\\u{" + c.toString(16) + "}" : String.fromCodePoint(c);
}

function show_val(D, N, d, v, chain) {
  if (D[d] === 7) {
    const fs = Object.values(typeof v === "boolean"
      ? { $: v ? "True" : "False" } : v);
    let a = d + 3;
    for (; N[D[a]] !== fs[0]; a += 4 + 2 * D[a + 2]) {}
    const o = "{[("[D[a + 3]];
    let s = o === "{" ? fs[0] + "{" : chain === o ? "" : o;
    for (const [j, f] of fs.slice(1).entries()) {
      if (o === "[" ? j === 0 && chain === o : j > 0) {
        s += ", ";
      }
      s += show_val(D, N, D[a + 5 + 2 * j], f, j === 1 && o !== "{" ? o : 0);
    }
    return o === "{" || chain !== o ? s + "}])"[D[a + 3]] : s;
  }
  return D[d] === 0 ? String(v)
    : D[d] === 1 ? f32_show(v).replace(/^-?\d+(?=e|$)/, "$&.0")
    : D[d] === 2 ? v + "n"
    : D[d] === 3 ? "'" + show_chr(v.codePointAt(0), "'") + "'"
    : D[d] === 4 ? "\"" + [...v].map((c) =>
      show_chr(c.codePointAt(0), "\"")).join("") + "\""
    : D[d] === 5 ? "{==}"
    : "[" + v.map((x) => show_val(D, N, D[d + 1], x, 0)).join(", ") + "]";
}

// Io
// ==

// Apple arm64 passes variadic fcntl flags on the stack, so io_sys
// binds fcntl there with the flags as the ninth fixed argument. A
// parked effect waits for fd (a write when out) or until at
// (performance.now()), either one undefined when unused; io_wake
// resumes k with the value of more, and undefined parks it again. The
// waits stay in deadline order, as io_park does in C.

function io_exit(main, show) {
  try {
    if (show !== null) {
      io_out(1, io_bytes(show_val(...show, 0, run_loop(main()), 0) + "\n"));
      process.exit(0);
    }
    process.exit(io_run(main));
  } catch (e) {
    io_errs(String(e));
    process.exit(1);
  }
}

function io_out(fd, data) {
  const fs = require("fs");
  let at = 0;
  while (at < data.length) {
    try {
      at += fs.writeSync(fd, data, at, data.length - at);
    } catch (e) {
      if (e.code === "EAGAIN" || e.code === "EINTR") {
        continue;
      }
      try {
        fs.writeSync(2, "bend: a short write on a standard stream\n");
      } catch (o) {
      }
      process.exit(1);
    }
  }
}

function io_errs(message) {
  io_out(2, io_bytes(message + "\n"));
}

function io_sys() {
  if (globalThis.BEND_SYS === undefined) {
    const ffi = require("bun:ffi");
    const mac = process.platform === "darwin";
    const err = mac ? "__error" : "__errno_location";
    const sel = mac ? "select$DARWIN_EXTSN" : "select";
    const T = { i: "i32", u: "u32", U: "u64", I: "i64", p: "ptr",
      c: "cstring" };
    const vari = mac && process.arch === "arm64";
    const lib = ffi.dlopen(mac ? "libSystem.dylib" : "libc.so.6",
      Object.fromEntries(("socket:iii>i bind:ipu>i listen:ii>i connect:ipu>i"
        + " accept:ipp>i send:ipUi>I recv:ipUi>I read:ipU>I pread:ipUI>I"
        + " sendto:ipUipu>I recvfrom:ipUipp>I close:i>i setsockopt:iiipu>i"
        + " " + sel + ":ipppp>i"
        + (vari ? " fcntl:iiiiiiiii>i" : " fcntl:iii>i") + " getsockopt:iiipp>i"
        + " strerror:i>c " + err + ":>p").split(" ").map((s) => {
        const [name, args, ret] = s.split(/[:>]/);
        return [name, { args: [...args].map((a) => T[a]), returns: T[ret] }];
      }))).symbols;
    const fcntl = (fd, cmd, arg) => vari
      ? lib.fcntl(fd, cmd, 0, 0, 0, 0, 0, 0, arg)
      : lib.fcntl(fd, cmd, arg);
    globalThis.BEND_SYS = { ...lib, fcntl, select: lib[sel],
      ptr: ffi.ptr, mac,
      errno: () => ffi.read.i32(lib[err](), 0) };
  }
  return globalThis.BEND_SYS;
}

// strerror needs bun:ffi; a host without it (node) gets the bare errno.
function io_strerror(code) {
  try {
    return String(io_sys().strerror(code));
  } catch (_) {
    return "errno " + code;
  }
}

function io_fail(code) {
  return { $: "Fail",
    error: io_tup(code >>> 0, io_strerror(code)) };
}

function io_done(value) {
  return { $: "Done", value };
}

function io_tup(...xs) {
  return xs.reduceRight((snd, fst) => ({ $: "Tuple", fst, snd }));
}

function io_bytes(text) {
  return new TextEncoder().encode(text);
}

function io_text(b, n) {
  return new TextDecoder("utf-8", { ignoreBOM: true }).decode(b.subarray(0, n));
}

// Bytes cross as they are (0..255), one List cell each, with no UTF-8 in
// either direction; io_unlist answers null if a value is past 255.
function io_list(b, n) {
  let xs = { $: "Nil" };
  while (n > 0) {
    xs = { $: "Con", head: b[--n], tail: xs };
  }
  return xs;
}

function io_unlist(xs) {
  const b = [];
  for (; xs.$ === "Con"; xs = xs.tail) {
    b.push(xs.head);
  }
  return b.some((x) => x > 255) ? null : Uint8Array.from(b);
}

function io_addr(host, port) {
  const part = host.split(".");
  const deci = (p) => /^(0|[1-9]\d{0,2})$/.test(p) && Number(p) < 256;
  if (port > 65535 || part.length !== 4 || !part.every(deci)) {
    return null;
  }
  const b = new Uint8Array(16);
  const head = io_sys().mac ? [16, 2] : [2, 0];
  b.set([...head, port >> 8, port & 255, ...part.map(Number)]);
  return b;
}

function io_push(fun, arg, fresh) {
  const io = globalThis.BEND_IO;
  io.runs.push({ fun, arg });
  io.live += fresh ? 1 : 0;
}

function io_wait(io, block) {
  const soon = io.waits[0]?.at ?? Infinity;
  const ms = !block ? 0 : soon === Infinity ? -1
    : Math.max(0, Math.ceil(soon - performance.now()));
  const fds = io.waits.filter((w) => w.fd !== undefined);
  const top = fds.reduce((m, w) => Math.max(m, w.fd), 0);
  const len = (top >> 6 << 3) + 8;
  const set = new Uint8Array(2 * len);
  const at = (w) => (w.out ? len : 0) + (w.fd >> 3);
  for (const w of fds) {
    set[at(w)] |= 1 << (w.fd & 7);
  }
  const tv = new BigInt64Array([BigInt(ms / 1000 | 0),
    BigInt(ms % 1000 * 1000)]);
  const sys = io_sys();
  if (sys.select(top + 1, sys.ptr(set), sys.ptr(set, len), null,
    ms < 0 ? null : sys.ptr(tv)) < 0) {
    if (sys.errno() !== 4) {
      throw "bend: the poller failed";
    }
    set.fill(0);
  }
  const now = performance.now();
  io.waits = io.waits.filter((w) => {
    const ready = w.at <= now || w.fd !== undefined
      && set[at(w)] & 1 << (w.fd & 7);
    if (ready) {
      io_push(io_wake, w, false);
    }
    return !ready;
  });
}

function io_wake(w) {
  const x = w.more();
  return x === undefined ? undefined : w.k(x);
}

function io_park_on(fd, out, k, more, at) {
  const ws = globalThis.BEND_IO.waits;
  const i = ws.findLastIndex((w) => (w.at ?? Infinity) <= (at ?? Infinity));
  ws.splice(i + 1, 0, { fd, out, k, more, at });
}

function io_run(m) {
  const io = { runs: [], live: 0, waits: [] };
  globalThis.BEND_IO = io;
  try {
    io_push(run_loop(m()), (x) => ({ $: "Emit", value: x }), true);
    let look = 0;
    for (let n = 0;; n += 1) {
      if (io.runs.length === 0) {
        if (io.live === 0) {
          return 0;
        }
        if (io.waits.length === 0) {
          io_errs("bend: deadlock: every computation waits on a channel");
          return 1;
        }
        io_wait(io, true);
        continue;
      }
      if ((n & 63) === 0 && io.waits.length > 0) {
        const now = performance.now();
        if (now >= look || io.waits[0].at <= now) {
          look = now + 10;
          io_wait(io, false);
        }
      }
      const s = io.runs.shift();
      let op = s.fun(s.arg);
      while (op !== undefined) {
        if (op.$ === "Emit") {
          io.live -= 1;
          break;
        }
        if (op.$ === "Halt") {
          io_errs(op.message);
          return op.code;
        }
        const need = op.need?.() ?? {};
        if (need.time || need.read) {
          const more = () => op.run(...op.args, op.kont);
          io_park_on(need.read ? op.args[0] : undefined, false, op.kont, more,
            need.read ? undefined : performance.now() + Number(op.args[0]));
          break;
        }
        const x = op.run(...op.args, op.kont);
        if (x === undefined) {
          break;
        }
        op = op.kont(x);
      }
    }
  } catch (req) {
    if (req instanceof RangeError) {
      throw "bend: memory fault (machine stack overflow?)";
    }
    if (req?.$ !== "$FFI") {
      throw req;
    }
    io_errs("bend: runtime fail-stop");
    return 1;
  }
}

cli(process.argv.slice(1));
io_exit($main$, null);