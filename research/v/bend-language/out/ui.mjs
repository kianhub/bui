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
// Program
// =======

function $fpick$(_c_0, _a_0, _b_0) {
  if (_c_0) {
    return _a_0;
  } else {
    return _b_0;
  }
}

function $len_or$(_l_0, _d_0) {
  if (_l_0.$ === "Auto") {
    return _d_0;
  } else {
    const _v_0 = _l_0["v"];
    return _v_0;
  }
}

function $main_of$(_a_0, _w_0, _h_0) {
  if (_a_0.$ === "Row") {
    return _w_0;
  } else {
    return _h_0;
  }
}

function $cross_of$(_a_0, _w_0, _h_0) {
  if (_a_0.$ === "Row") {
    return _h_0;
  } else {
    return _w_0;
  }
}

function $text_w$(_s_0, _size_0) {
  const _x_0 = ($F32$from_nat$([..._s_0].length));
  const _x_1 = Math.fround(_x_0 * _size_0);
  return Math.fround(_x_1 * 0.6000000238418579);
}

function $style$(_axis_0, _w_0, _h_0, _grow_0, _pad_0, _gap_0, _bg_0) {
  return {$: "Style", "axis": _axis_0, "justify": {$: "JStart"}, "align": {$: "AStretch"}, "w": _w_0, "h": _h_0, "grow": _grow_0, "pad": _pad_0, "gap": _gap_0, "bg": _bg_0};
}

function $plain$() {
  return {$: "Style", "axis": {$: "Row"}, "justify": {$: "JStart"}, "align": {$: "AStart"}, "w": {$: "Auto"}, "h": {$: "Auto"}, "grow": 0, "pad": 0, "gap": 0, "bg": 0};
}

function $grow_of$(_st_0) {
  const _grow_0 = _st_0["grow"];
  return _grow_0;
}

function $tot$($0, $1, $2) {
  for (;;) {
    {
      const _ks_0 = $0;
      const _a_0 = $1;
      const _acc_0 = $2;
      if (_ks_0.$ === "Nil") {
        return _acc_0;
      } else {
        const _t_0 = _ks_0["head"];
        const _st_0 = _t_0["st"];
        const _iw_0 = _t_0["iw"];
        const _ih_0 = _t_0["ih"];
        const _t_1 = _ks_0["tail"];
        const _m_0 = _acc_0["main"];
        const _c_0 = _acc_0["cross"];
        const _g_0 = _acc_0["grow"];
        const _n_0 = _acc_0["n"];
        const _x_0 = ($main_of$(_a_0, _iw_0, _ih_0));
        const _x_1 = ($grow_of$(_st_0));
        $0 = _t_1;
        $1 = _a_0;
        $2 = {$: "Tot", "main": Math.fround(_m_0 + _x_0), "cross": ($F32$max$(_c_0, ($cross_of$(_a_0, _iw_0, _ih_0)))), "grow": Math.fround(_g_0 + _x_1), "n": ((_n_0 + 1) >>> 0)};
        continue;
      }
    }
  }
}

function $stack_wh$($0, $1, $2) {
  for (;;) {
    {
      const _ks_0 = $0;
      const _w_0 = $1;
      const _h_0 = $2;
      if (_ks_0.$ === "Nil") {
        return {$: "Rect", "x": 0, "y": 0, "w": _w_0, "h": _h_0};
      } else {
        const _t_0 = _ks_0["head"];
        const _iw_0 = _t_0["iw"];
        const _ih_0 = _t_0["ih"];
        const _t_1 = _ks_0["tail"];
        $0 = _t_1;
        $1 = ($F32$max$(_w_0, _iw_0));
        $2 = ($F32$max$(_h_0, _ih_0));
        continue;
      }
    }
  }
}

function $gaps$(_gap_0, _n_0) {
  const _x_0 = ($U32$max$(_n_0, 1));
  const _x_1 = ((_x_0 - 1) >>> 0);
  const _x_2 = Math.fround(_x_1);
  return Math.fround(_gap_0 * _x_2);
}

function $flow_box$k$(_st_0, _kids_0, _paint_0, _hit_0, _t_0) {
  const _ax_0 = _st_0["axis"];
  const _j_0 = _st_0["justify"];
  const _al_0 = _st_0["align"];
  const _w_0 = _st_0["w"];
  const _h_0 = _st_0["h"];
  const _grow_0 = _st_0["grow"];
  const _pad_0 = _st_0["pad"];
  const _gap_0 = _st_0["gap"];
  const _bg_0 = _st_0["bg"];
  const _m_0 = _t_0["main"];
  const _c_0 = _t_0["cross"];
  const _n_0 = _t_0["n"];
  const _x_0 = ($gaps$(_gap_0, _n_0));
  const _x_1 = Math.fround(_m_0 + _x_0);
  const _x_2 = Math.fround(2 * _pad_0);
  const _mm_0 = Math.fround(_x_1 + _x_2);
  const _x_3 = Math.fround(2 * _pad_0);
  const _cc_0 = Math.fround(_c_0 + _x_3);
  return {$: "M", "st": {$: "Style", "axis": _ax_0, "justify": _j_0, "align": _al_0, "w": _w_0, "h": _h_0, "grow": _grow_0, "pad": _pad_0, "gap": _gap_0, "bg": _bg_0}, "iw": ($len_or$(_w_0, ($main_of$(_ax_0, _mm_0, _cc_0)))), "ih": ($len_or$(_h_0, ($cross_of$(_ax_0, _mm_0, _cc_0)))), "paint": _paint_0, "hit": _hit_0, "stack": false, "kids": _kids_0};
}

function $axis_of$(_st_0) {
  const _ax_0 = _st_0["axis"];
  return _ax_0;
}

function $flow_box$(_st_0, _kids_0, _paint_0, _hit_0) {
  return $flow_box$k$(_st_0, _kids_0, _paint_0, _hit_0, ($tot$(_kids_0, ($axis_of$(_st_0)), {$: "Tot", "main": 0, "cross": 0, "grow": 0, "n": 0})));
}

function $stack_box$k$(_st_0, _kids_0, _r_0) {
  const _ax_0 = _st_0["axis"];
  const _j_0 = _st_0["justify"];
  const _al_0 = _st_0["align"];
  const _w_0 = _st_0["w"];
  const _h_0 = _st_0["h"];
  const _grow_0 = _st_0["grow"];
  const _pad_0 = _st_0["pad"];
  const _gap_0 = _st_0["gap"];
  const _bg_0 = _st_0["bg"];
  const _sw_0 = _r_0["w"];
  const _sh_0 = _r_0["h"];
  const _x_1 = Math.fround(2 * _pad_0);
  const _x_2 = Math.fround(2 * _pad_0);
  return {$: "M", "st": {$: "Style", "axis": _ax_0, "justify": _j_0, "align": _al_0, "w": _w_0, "h": _h_0, "grow": _grow_0, "pad": _pad_0, "gap": _gap_0, "bg": _bg_0}, "iw": ($len_or$(_w_0, Math.fround(_sw_0 + _x_1))), "ih": ($len_or$(_h_0, Math.fround(_sh_0 + _x_2))), "paint": {$: "PFill", "color": _bg_0}, "hit": {$: "None"}, "stack": true, "kids": _kids_0};
}

function $stack_box$(_st_0, _kids_0) {
  return $stack_box$k$(_st_0, _kids_0, ($stack_wh$(_kids_0, 0, 0)));
}

function $leaf$(_st_0, _iw_0, _ih_0, _paint_0, _hit_0) {
  const _ax_0 = _st_0["axis"];
  const _j_0 = _st_0["justify"];
  const _al_0 = _st_0["align"];
  const _w_0 = _st_0["w"];
  const _h_0 = _st_0["h"];
  const _grow_0 = _st_0["grow"];
  const _pad_0 = _st_0["pad"];
  const _gap_0 = _st_0["gap"];
  const _bg_0 = _st_0["bg"];
  const _x_0 = Math.fround(2 * _pad_0);
  const _x_1 = Math.fround(2 * _pad_0);
  return {$: "M", "st": {$: "Style", "axis": _ax_0, "justify": _j_0, "align": _al_0, "w": _w_0, "h": _h_0, "grow": _grow_0, "pad": _pad_0, "gap": _gap_0, "bg": _bg_0}, "iw": ($len_or$(_w_0, Math.fround(_iw_0 + _x_0))), "ih": ($len_or$(_h_0, Math.fround(_ih_0 + _x_1))), "paint": _paint_0, "hit": _hit_0, "stack": false, "kids": {$: "Nil"}};
}

function $bg_of$(_st_0) {
  const _bg_0 = _st_0["bg"];
  return _bg_0;
}

function $measure$(_ns_0) {
  if (_ns_0.$ === "Nil") {
    return {$: "Nil"};
  } else {
    const _t_0 = _ns_0["head"];
    if (_t_0.$ === "Div") {
      const _st_0 = _t_0["st"];
      const _ks_0 = _t_0["kids"];
      const _t_1 = _ns_0["tail"];
      return {$: "Con", "head": ($flow_box$(_st_0, ($measure$(_ks_0)), {$: "PFill", "color": ($bg_of$(_st_0))}, {$: "None"})), "tail": ($measure$(_t_1))};
    } else if (_t_0.$ === "ScrollView") {
      const _st_1 = _t_0["st"];
      const _ks_1 = _t_0["kids"];
      const _t_2 = _ns_0["tail"];
      return {$: "Con", "head": ($flow_box$(_st_1, ($measure$(_ks_1)), {$: "PFill", "color": ($bg_of$(_st_1))}, {$: "None"})), "tail": ($measure$(_t_2))};
    } else if (_t_0.$ === "Overlay") {
      const _st_2 = _t_0["st"];
      const _ks_2 = _t_0["kids"];
      const _t_3 = _ns_0["tail"];
      return {$: "Con", "head": ($stack_box$(_st_2, ($measure$(_ks_2)))), "tail": ($measure$(_t_3))};
    } else if (_t_0.$ === "Text") {
      const _st_3 = _t_0["st"];
      const _s_0 = _t_0["s"];
      const _size_0 = _t_0["size"];
      const _t_4 = _ns_0["tail"];
      return {$: "Con", "head": ($leaf$(_st_3, ($text_w$(_s_0, _size_0)), Math.fround(_size_0 * 1.2000000476837158), {$: "PText", "s": _s_0, "size": _size_0, "color": 15790320}, {$: "None"})), "tail": ($measure$(_t_4))};
    } else if (_t_0.$ === "Label") {
      const _st_4 = _t_0["st"];
      const _s_1 = _t_0["s"];
      const _t_5 = _ns_0["tail"];
      return {$: "Con", "head": ($leaf$(_st_4, ($text_w$(_s_1, 14)), 16.799999237060547, {$: "PText", "s": _s_1, "size": 14, "color": 13421772}, {$: "None"})), "tail": ($measure$(_t_5))};
    } else if (_t_0.$ === "Heading") {
      const _st_5 = _t_0["st"];
      const _s_2 = _t_0["s"];
      const _t_6 = _ns_0["tail"];
      return {$: "Con", "head": ($leaf$(_st_5, ($text_w$(_s_2, 24)), 28.799999237060547, {$: "PText", "s": _s_2, "size": 24, "color": 16777215}, {$: "None"})), "tail": ($measure$(_t_6))};
    } else if (_t_0.$ === "Link") {
      const _st_6 = _t_0["st"];
      const _s_3 = _t_0["s"];
      const _m_0 = _t_0["on_click"];
      const _t_7 = _ns_0["tail"];
      return {$: "Con", "head": ($leaf$(_st_6, ($text_w$(_s_3, 14)), 16.799999237060547, {$: "PText", "s": _s_3, "size": 14, "color": 6724095}, {$: "Some", "value": _m_0})), "tail": ($measure$(_t_7))};
    } else if (_t_0.$ === "Button") {
      const _st_7 = _t_0["st"];
      const _s_4 = _t_0["label"];
      const _m_1 = _t_0["on_click"];
      const _t_8 = _ns_0["tail"];
      return {$: "Con", "head": ($leaf$(_st_7, ($text_w$(_s_4, 14)), 16.799999237060547, {$: "PText", "s": _s_4, "size": 14, "color": 16777215}, {$: "Some", "value": _m_1})), "tail": ($measure$(_t_8))};
    } else if (_t_0.$ === "IconButton") {
      const _st_8 = _t_0["st"];
      const _i_0 = _t_0["icon"];
      const _m_2 = _t_0["on_click"];
      const _t_9 = _ns_0["tail"];
      return {$: "Con", "head": ($leaf$(_st_8, 16, 16, {$: "PFill", "color": _i_0}, {$: "Some", "value": _m_2})), "tail": ($measure$(_t_9))};
    } else if (_t_0.$ === "Checkbox") {
      const _st_9 = _t_0["st"];
      const _m_3 = _t_0["on_click"];
      const _t_10 = _ns_0["tail"];
      return {$: "Con", "head": ($leaf$(_st_9, 16, 16, {$: "PFill", "color": 0}, {$: "Some", "value": _m_3})), "tail": ($measure$(_t_10))};
    } else if (_t_0.$ === "Switch") {
      const _st_10 = _t_0["st"];
      const _m_4 = _t_0["on_click"];
      const _t_11 = _ns_0["tail"];
      return {$: "Con", "head": ($leaf$(_st_10, 32, 16, {$: "PFill", "color": 0}, {$: "Some", "value": _m_4})), "tail": ($measure$(_t_11))};
    } else if (_t_0.$ === "Slider") {
      const _st_11 = _t_0["st"];
      const _v_0 = _t_0["v"];
      const _m_5 = _t_0["on_click"];
      const _t_12 = _ns_0["tail"];
      return {$: "Con", "head": ($leaf$(_st_11, 120, 16, {$: "PBar", "v": _v_0, "color": 3381759}, {$: "Some", "value": _m_5})), "tail": ($measure$(_t_12))};
    } else if (_t_0.$ === "Input") {
      const _st_12 = _t_0["st"];
      const _s_5 = _t_0["text"];
      const _m_6 = _t_0["on_click"];
      const _t_13 = _ns_0["tail"];
      return {$: "Con", "head": ($leaf$(_st_12, ($F32$max$(160, ($text_w$(_s_5, 14)))), 16.799999237060547, {$: "PText", "s": _s_5, "size": 14, "color": 16777215}, {$: "Some", "value": _m_6})), "tail": ($measure$(_t_13))};
    } else if (_t_0.$ === "Img") {
      const _st_13 = _t_0["st"];
      const _w_0 = _t_0["w"];
      const _h_0 = _t_0["h"];
      const _tex_0 = _t_0["tex"];
      const _t_14 = _ns_0["tail"];
      return {$: "Con", "head": ($leaf$(_st_13, _w_0, _h_0, {$: "PFill", "color": _tex_0}, {$: "None"})), "tail": ($measure$(_t_14))};
    } else if (_t_0.$ === "Icon") {
      const _st_14 = _t_0["st"];
      const _g_0 = _t_0["glyph"];
      const _t_15 = _ns_0["tail"];
      return {$: "Con", "head": ($leaf$(_st_14, 16, 16, {$: "PFill", "color": _g_0}, {$: "None"})), "tail": ($measure$(_t_15))};
    } else if (_t_0.$ === "Spacer") {
      const _st_15 = _t_0["st"];
      const _t_16 = _ns_0["tail"];
      return {$: "Con", "head": ($leaf$(_st_15, 0, 0, {$: "PNone"}, {$: "None"})), "tail": ($measure$(_t_16))};
    } else if (_t_0.$ === "Divider") {
      const _st_16 = _t_0["st"];
      const _t_17 = _ns_0["tail"];
      return {$: "Con", "head": ($leaf$(_st_16, 1, 1, {$: "PFill", "color": 4473924}, {$: "None"})), "tail": ($measure$(_t_17))};
    } else if (_t_0.$ === "Badge") {
      const _st_17 = _t_0["st"];
      const _n_0 = _t_0["n"];
      const _t_18 = _ns_0["tail"];
      return {$: "Con", "head": ($leaf$(_st_17, ($text_w$(($U32$show$(_n_0)), 12)), 14.399999618530273, {$: "PText", "s": ($U32$show$(_n_0)), "size": 12, "color": 16777215}, {$: "None"})), "tail": ($measure$(_t_18))};
    } else if (_t_0.$ === "Progress") {
      const _st_18 = _t_0["st"];
      const _v_1 = _t_0["v"];
      const _t_19 = _ns_0["tail"];
      return {$: "Con", "head": ($leaf$(_st_18, 120, 6, {$: "PBar", "v": _v_1, "color": 65280}, {$: "None"})), "tail": ($measure$(_t_19))};
    } else {
      const _st_19 = _t_0["st"];
      const _w_1 = _t_0["w"];
      const _h_1 = _t_0["h"];
      const _seed_0 = _t_0["seed"];
      const _t_20 = _ns_0["tail"];
      return {$: "Con", "head": ($leaf$(_st_19, _w_1, _h_1, {$: "PFill", "color": _seed_0}, {$: "None"})), "tail": ($measure$(_t_20))};
    }
  }
}

function $align_off$(_al_0, _room_0) {
  if (_al_0.$ === "AStart") {
    return 0;
  } else if (_al_0.$ === "ACenter") {
    return Math.fround(_room_0 / 2);
  } else if (_al_0.$ === "AEnd") {
    return _room_0;
  } else {
    return 0;
  }
}

function $is_stretch$(_al_0) {
  if (_al_0.$ === "AStretch") {
    return true;
  } else {
    return false;
  }
}

function $kid_rect$fin$(_stack_0, _axis_0, _x_0, _y_0, _w_0, _h_0, _cur_0, _off_0, _main_0, _cross_0) {
  if (_stack_0) {
    return {$: "Rect", "x": _x_0, "y": _y_0, "w": _w_0, "h": _h_0};
  } else {
    if (_axis_0.$ === "Row") {
      return {$: "Rect", "x": _cur_0, "y": Math.fround(_y_0 + _off_0), "w": _main_0, "h": _cross_0};
    } else {
      return {$: "Rect", "x": Math.fround(_x_0 + _off_0), "y": _cur_0, "w": _cross_0, "h": _main_0};
    }
  }
}

function $kid_rect$(_c_0, _cur_0, _st_0, _iw_0, _ih_0) {
  const _axis_0 = _c_0["axis"];
  const _al_0 = _c_0["align"];
  const _x_0 = _c_0["x"];
  const _y_0 = _c_0["y"];
  const _w_0 = _c_0["w"];
  const _h_0 = _c_0["h"];
  const _pg_0 = _c_0["per_grow"];
  const _stack_0 = _c_0["stack"];
  const _inner_cross_0 = ($cross_of$(_axis_0, _w_0, _h_0));
  const _x_1 = ($grow_of$(_st_0));
  const _x_2 = ($main_of$(_axis_0, _iw_0, _ih_0));
  const _x_3 = Math.fround(_x_1 * _pg_0);
  const _main_0 = Math.fround(_x_2 + _x_3);
  const _cross_0 = ($fpick$(($is_stretch$(_al_0)), _inner_cross_0, ($cross_of$(_axis_0, _iw_0, _ih_0))));
  return $kid_rect$fin$(_stack_0, _axis_0, _x_0, _y_0, _w_0, _h_0, _cur_0, ($align_off$(_al_0, Math.fround(_inner_cross_0 - _cross_0))), _main_0, _cross_0);
}

function $next_cur$(_c_0, _cur_0, _r_0) {
  const _axis_0 = _c_0["axis"];
  const _gap_0 = _c_0["gap"];
  const _stack_0 = _c_0["stack"];
  const _rw_0 = _r_0["w"];
  const _rh_0 = _r_0["h"];
  const _x_1 = ($main_of$(_axis_0, _rw_0, _rh_0));
  const _x_2 = Math.fround(_cur_0 + _x_1);
  return $fpick$(_stack_0, _cur_0, Math.fround(_x_2 + _gap_0));
}

function $justify$(_j_0, _free_0, _gap_0, _n_0, _grow_0) {
  if (_j_0.$ === "JStart") {
    return {$: "Rect", "x": 0, "y": 0, "w": _gap_0, "h": 0};
  } else if (_j_0.$ === "JCenter") {
    return {$: "Rect", "x": ($fpick$((_grow_0 > 0), 0, Math.fround(_free_0 / 2))), "y": 0, "w": _gap_0, "h": 0};
  } else if (_j_0.$ === "JEnd") {
    return {$: "Rect", "x": ($fpick$((_grow_0 > 0), 0, _free_0)), "y": 0, "w": _gap_0, "h": 0};
  } else {
    const _x_0 = ((_n_0 - 1) >>> 0);
    const _x_1 = Math.fround(_x_0);
    const _x_2 = Math.fround(_free_0 / _x_1);
    return {$: "Rect", "x": 0, "y": 0, "w": ($fpick$((_n_0 > 1), Math.fround(_gap_0 + _x_2), _gap_0)), "h": 0};
  }
}

function $enter$fin$(_ax_0, _al_0, _x0_0, _y0_0, _iw_0, _ih_0, _pg_0, _stack_0, _jg_0) {
  const _off_0 = _jg_0["x"];
  const _gap2_0 = _jg_0["w"];
  const _x_0 = ($main_of$(_ax_0, _x0_0, _y0_0));
  return {$: "Ctx", "axis": _ax_0, "align": _al_0, "x": _x0_0, "y": _y0_0, "w": _iw_0, "h": _ih_0, "per_grow": _pg_0, "gap": _gap2_0, "start": Math.fround(_x_0 + _off_0), "stack": _stack_0};
}

function $enter$k$(_st_0, _stack_0, _r_0, _t_0) {
  const _ax_0 = _st_0["axis"];
  const _j_0 = _st_0["justify"];
  const _al_0 = _st_0["align"];
  const _pad_0 = _st_0["pad"];
  const _gap_0 = _st_0["gap"];
  const _x_0 = _r_0["x"];
  const _y_0 = _r_0["y"];
  const _rw_0 = _r_0["w"];
  const _rh_0 = _r_0["h"];
  const _m_0 = _t_0["main"];
  const _g_0 = _t_0["grow"];
  const _n_0 = _t_0["n"];
  const _x_1 = Math.fround(2 * _pad_0);
  const _iw_0 = ($F32$max$(0, Math.fround(_rw_0 - _x_1)));
  const _x_2 = Math.fround(2 * _pad_0);
  const _ih_0 = ($F32$max$(0, Math.fround(_rh_0 - _x_2)));
  const _x_3 = ($main_of$(_ax_0, _iw_0, _ih_0));
  const _x_4 = Math.fround(_x_3 - _m_0);
  const _x_5 = ($gaps$(_gap_0, _n_0));
  const _free_0 = ($F32$max$(0, Math.fround(_x_4 - _x_5)));
  const _pg_0 = ($fpick$((_g_0 > 0), Math.fround(_free_0 / _g_0), 0));
  return $enter$fin$(_ax_0, _al_0, Math.fround(_x_0 + _pad_0), Math.fround(_y_0 + _pad_0), _iw_0, _ih_0, _pg_0, _stack_0, ($justify$(_j_0, _free_0, _gap_0, _n_0, _g_0)));
}

function $enter$(_st_0, _stack_0, _r_0, _kids_0) {
  return $enter$k$(_st_0, _stack_0, _r_0, ($tot$(_kids_0, ($axis_of$(_st_0)), {$: "Tot", "main": 0, "cross": 0, "grow": 0, "n": 0})));
}

function $ctx_start$(_c_0) {
  const _start_0 = _c_0["start"];
  return _start_0;
}

function $place$(_ms_0, _c_0, _cur_0) {
  if (_ms_0.$ === "Nil") {
    return {$: "Nil"};
  } else {
    const _t_0 = _ms_0["head"];
    const _st_0 = _t_0["st"];
    const _iw_0 = _t_0["iw"];
    const _ih_0 = _t_0["ih"];
    const _paint_0 = _t_0["paint"];
    const _hit_0 = _t_0["hit"];
    const _stk_0 = _t_0["stack"];
    const _kids_0 = _t_0["kids"];
    const _t_1 = _ms_0["tail"];
    const _r_0 = ($kid_rect$(_c_0, _cur_0, _st_0, _iw_0, _ih_0));
    const _cc_0 = ($enter$(_st_0, _stk_0, _r_0, _kids_0));
    return {$: "Con", "head": {$: "L", "r": _r_0, "paint": _paint_0, "hit": _hit_0, "kids": ($place$(_kids_0, _cc_0, ($ctx_start$(_cc_0))))}, "tail": ($place$(_t_1, _c_0, ($next_cur$(_c_0, _cur_0, _r_0))))};
  }
}

function $root_ctx$(_w_0, _h_0) {
  return {$: "Ctx", "axis": {$: "Col"}, "align": {$: "AStretch"}, "x": 0, "y": 0, "w": _w_0, "h": _h_0, "per_grow": 0, "gap": 0, "start": 0, "stack": false};
}

function $hits$($0, $1) {
  for (;;) {
    {
      const _ls_0 = $0;
      const _acc_0 = $1;
      if (_ls_0.$ === "Nil") {
        return _acc_0;
      } else {
        const _t_0 = _ls_0["head"];
        const _r_0 = _t_0["r"];
        const _t_1 = _t_0["hit"];
        if (_t_1.$ === "Some") {
          const _m_0 = _t_1["value"];
          const _kids_0 = _t_0["kids"];
          const _t_2 = _ls_0["tail"];
          $0 = _t_2;
          $1 = ($hits$(_kids_0, {$: "Con", "head": {$: "Hit", "r": _r_0, "m": _m_0}, "tail": _acc_0}));
          continue;
        } else {
          const _kids_1 = _t_0["kids"];
          const _t_3 = _ls_0["tail"];
          $0 = _t_3;
          $1 = ($hits$(_kids_1, _acc_0));
          continue;
        }
      }
    }
  }
}

function $inside$(_r_0, _px_0, _py_0) {
  const _x_0 = _r_0["x"];
  const _y_0 = _r_0["y"];
  const _w_0 = _r_0["w"];
  const _h_0 = _r_0["h"];
  const _x_1 = Math.fround(_x_0 + _w_0);
  const _x_2 = Math.fround(_y_0 + _h_0);
  return $Bool$and$(($Bool$and$(($Bool$and$((_px_0 >= _x_0), (_px_0 < _x_1))), (_py_0 >= _y_0))), (_py_0 < _x_2));
}

function $find_hit$k$(_c_0, _m_0, _rest_0) {
  if (_c_0) {
    return {$: "Some", "value": _m_0};
  } else {
    return _rest_0;
  }
}

function $find_hit$(_hs_0, _px_0, _py_0) {
  if (_hs_0.$ === "Nil") {
    return {$: "None"};
  } else {
    const _t_0 = _hs_0["head"];
    const _r_0 = _t_0["r"];
    const _m_0 = _t_0["m"];
    const _t_1 = _hs_0["tail"];
    return $find_hit$k$(($inside$(_r_0, _px_0, _py_0)), _m_0, ($find_hit$(_t_1, _px_0, _py_0)));
  }
}

function $upick$(_c_0, _a_0, _b_0) {
  if (_c_0) {
    return _a_0;
  } else {
    return _b_0;
  }
}

function $ent$inc$(_e_0, _by_0) {
  if (_e_0.$ === "Counter") {
    const _n_0 = _e_0["n"];
    return {$: "Counter", "n": ((_n_0 + _by_0) >>> 0)};
  } else {
    return _e_0;
  }
}

function $ent$dec$(_e_0) {
  if (_e_0.$ === "Counter") {
    const _n_0 = _e_0["n"];
    return {$: "Counter", "n": ($upick$((_n_0 > 0), ((_n_0 - 1) >>> 0), 0))};
  } else {
    return _e_0;
  }
}

function $ent$toggle$(_e_0) {
  if (_e_0.$ === "Check") {
    const _on_0 = _e_0["on"];
    return {$: "Check", "on": ($Bool$not$(_on_0))};
  } else {
    return _e_0;
  }
}

function $ent$reset$(_e_0) {
  if (_e_0.$ === "Counter") {
    return {$: "Counter", "n": 0};
  } else {
    return _e_0;
  }
}

function $ent$level$(_e_0, _v_0) {
  if (_e_0.$ === "Level") {
    return {$: "Level", "v": _v_0};
  } else {
    return _e_0;
  }
}

function $ent$apply$(_m_0, _e_0) {
  if (_m_0.$ === "Inc") {
    const _by_0 = _m_0["by"];
    return $ent$inc$(_e_0, _by_0);
  } else if (_m_0.$ === "Dec") {
    return $ent$dec$(_e_0);
  } else if (_m_0.$ === "Reset") {
    return $ent$reset$(_e_0);
  } else if (_m_0.$ === "Toggle") {
    return $ent$toggle$(_e_0);
  } else if (_m_0.$ === "SetLevel") {
    const _v_0 = _m_0["v"];
    return $ent$level$(_e_0, _v_0);
  } else {
    return _e_0;
  }
}

function $msg_id$(_m_0) {
  if (_m_0.$ === "Inc") {
    const _id_0 = _m_0["id"];
    return _id_0;
  } else if (_m_0.$ === "Dec") {
    const _id_1 = _m_0["id"];
    return _id_1;
  } else if (_m_0.$ === "Reset") {
    const _id_2 = _m_0["id"];
    return _id_2;
  } else if (_m_0.$ === "Toggle") {
    const _id_3 = _m_0["id"];
    return _id_3;
  } else if (_m_0.$ === "SetLevel") {
    const _id_4 = _m_0["id"];
    return _id_4;
  } else {
    return 3;
  }
}

function $store$with$(_r_0, _id_0, _m_0) {
  const _a_0 = _r_0["fst"];
  const _e_0 = _r_0["snd"];
  const _x_0 = ($ent$apply$(_m_0, _e_0));
  return (_a_0[_id_0 % _a_0.length] = _x_0, _a_0);
}

function $update$(_m_0, _s_0) {
  const _id_0 = ($msg_id$(_m_0));
  return $store$with$({$: "Tuple", fst: _s_0, snd: _s_0[_id_0 % _s_0.length]}, _id_0, _m_0);
}

function $ent$n$(_e_0) {
  if (_e_0.$ === "Counter") {
    const _n_0 = _e_0["n"];
    return _n_0;
  } else {
    return 0;
  }
}

function $ent$on$(_e_0) {
  if (_e_0.$ === "Check") {
    const _on_0 = _e_0["on"];
    return _on_0;
  } else {
    return false;
  }
}

function $ent$v$(_e_0) {
  if (_e_0.$ === "Level") {
    const _v_0 = _e_0["v"];
    return _v_0;
  } else {
    return 0;
  }
}

function $IMap$bit$(_k_0, _d_0) {
  const _x_0 = (_d_0 >= 32 ? 0 : (_k_0 >>> _d_0) >>> 0);
  const _x_1 = ((_x_0 & 1) >>> 0);
  return (_x_1 === 1);
}

function $IMap$pick$(_b_0, _lo_0, _hi_0) {
  if (_b_0) {
    return _hi_0;
  } else {
    return _lo_0;
  }
}

function $IMap$node$(_b_0, _lo_0, _hi_0, _sub_0) {
  if (_b_0) {
    return {$: "INode", "lo": _lo_0, "hi": _sub_0};
  } else {
    return {$: "INode", "lo": _sub_0, "hi": _hi_0};
  }
}

function $IMap$leaf_or$(_same_0, _a_0, _b_0) {
  if (_same_0) {
    return _a_0;
  } else {
    return _b_0;
  }
}

function $IMap$put$(_fuel_0, _m_0, _d_0, _k_0, _v_0) {
  if (_fuel_0 === 0) {
    return {$: "ILeaf", "k": _k_0, "v": _v_0};
  } else {
    const _p_0 = (_fuel_0 - 1);
    if (_m_0.$ === "ITip") {
      return {$: "ILeaf", "k": _k_0, "v": _v_0};
    } else if (_m_0.$ === "ILeaf") {
      const _k2_0 = _m_0["k"];
      const _v2_0 = _m_0["v"];
      return $IMap$leaf_or$((_k_0 === _k2_0), {$: "ILeaf", "k": _k_0, "v": _v_0}, ($IMap$put$(_p_0, ($IMap$put$(_p_0, {$: "INode", "lo": {$: "ITip"}, "hi": {$: "ITip"}}, _d_0, _k2_0, _v2_0)), _d_0, _k_0, _v_0)));
    } else {
      const _lo_0 = _m_0["lo"];
      const _hi_0 = _m_0["hi"];
      const _b_0 = ($IMap$bit$(_k_0, _d_0));
      return $IMap$node$(_b_0, _lo_0, _hi_0, ($IMap$put$(_p_0, ($IMap$pick$(_b_0, _lo_0, _hi_0)), nat_chk(_d_0 + 1), _k_0, _v_0)));
    }
  }
}

function $IMap$hit$(_same_0, _v_0) {
  if (_same_0) {
    return {$: "Some", "value": _v_0};
  } else {
    return {$: "None"};
  }
}

function $IMap$get$($0, $1, $2, $3) {
  for (;;) {
    {
      const _fuel_0 = $0;
      const _m_0 = $1;
      const _d_0 = $2;
      const _k_0 = $3;
      if (_fuel_0 === 0) {
        return {$: "None"};
      } else {
        const _p_0 = (_fuel_0 - 1);
        if (_m_0.$ === "ITip") {
          return {$: "None"};
        } else if (_m_0.$ === "ILeaf") {
          const _k2_0 = _m_0["k"];
          const _v_0 = _m_0["v"];
          return $IMap$hit$((_k_0 === _k2_0), _v_0);
        } else {
          const _lo_0 = _m_0["lo"];
          const _hi_0 = _m_0["hi"];
          $0 = _p_0;
          $1 = ($IMap$pick$(($IMap$bit$(_k_0, _d_0)), _lo_0, _hi_0));
          $2 = nat_chk(_d_0 + 1);
          $3 = _k_0;
          continue;
        }
      }
    }
  }
}

function $pad$(_p_0) {
  return {$: "Style", "axis": {$: "Row"}, "justify": {$: "JStart"}, "align": {$: "AStart"}, "w": {$: "Auto"}, "h": {$: "Auto"}, "grow": 0, "pad": _p_0, "gap": 0, "bg": 3355443};
}

function $row$(_h_0, _j_0, _al_0) {
  return {$: "Style", "axis": {$: "Row"}, "justify": _j_0, "align": _al_0, "w": {$: "Auto"}, "h": {$: "Px", "v": _h_0}, "grow": 0, "pad": 4, "gap": 8, "bg": 3158064};
}

function $grow1$() {
  return {$: "Style", "axis": {$: "Row"}, "justify": {$: "JStart"}, "align": {$: "AStart"}, "w": {$: "Auto"}, "h": {$: "Auto"}, "grow": 1, "pad": 0, "gap": 0, "bg": 0};
}

function $tree$(_c_0, _on_0, _lv_0) {
  return {$: "Div", "st": {$: "Style", "axis": {$: "Col"}, "justify": {$: "JStart"}, "align": {$: "AStretch"}, "w": {$: "Auto"}, "h": {$: "Auto"}, "grow": 0, "pad": 16, "gap": 8, "bg": 2105376}, "kids": {$: "Con", "head": {$: "Heading", "st": ($plain$()), "s": "Counter"}, "tail": {$: "Con", "head": {$: "Div", "st": ($row$(40, {$: "JStart"}, {$: "ACenter"})), "kids": {$: "Con", "head": {$: "Button", "st": ($pad$(6)), "label": "-", "on_click": {$: "Dec", "id": 0}}, "tail": {$: "Con", "head": {$: "Text", "st": ($pad$(6)), "s": ($U32$show$(_c_0)), "size": 14}, "tail": {$: "Con", "head": {$: "Button", "st": ($pad$(6)), "label": "+", "on_click": {$: "Inc", "id": 0, "by": 1}}, "tail": {$: "Con", "head": {$: "Spacer", "st": ($grow1$())}, "tail": {$: "Con", "head": {$: "Badge", "st": ($pad$(2)), "n": _c_0}, "tail": {$: "Con", "head": {$: "Button", "st": ($pad$(6)), "label": "reset", "on_click": {$: "Reset", "id": 0}}, "tail": {$: "Nil"}}}}}}}}, "tail": {$: "Con", "head": {$: "Div", "st": ($row$(28, {$: "JStart"}, {$: "ACenter"})), "kids": {$: "Con", "head": {$: "Checkbox", "st": ($plain$()), "on": _on_0, "on_click": {$: "Toggle", "id": 1}}, "tail": {$: "Con", "head": {$: "Label", "st": ($plain$()), "s": "enabled"}, "tail": {$: "Con", "head": {$: "Switch", "st": ($plain$()), "on": _on_0, "on_click": {$: "Toggle", "id": 1}}, "tail": {$: "Nil"}}}}}, "tail": {$: "Con", "head": {$: "Div", "st": ($row$(24, {$: "JBetween"}, {$: "AStretch"})), "kids": {$: "Con", "head": {$: "Slider", "st": ($plain$()), "v": _lv_0, "on_click": {$: "SetLevel", "id": 2, "v": 0.75}}, "tail": {$: "Con", "head": {$: "Progress", "st": ($plain$()), "v": _lv_0}, "tail": {$: "Nil"}}}}, "tail": {$: "Con", "head": {$: "Overlay", "st": ($pad$(0)), "kids": {$: "Con", "head": {$: "Img", "st": ($plain$()), "w": 64, "h": 64, "tex": 255}, "tail": {$: "Con", "head": {$: "Icon", "st": ($plain$()), "glyph": 16711680}, "tail": {$: "Nil"}}}}, "tail": {$: "Con", "head": {$: "Divider", "st": ($plain$())}, "tail": {$: "Con", "head": {$: "ScrollView", "st": {$: "Style", "axis": {$: "Row"}, "justify": {$: "JEnd"}, "align": {$: "ACenter"}, "w": {$: "Auto"}, "h": {$: "Px", "v": 48}, "grow": 0, "pad": 4, "gap": 8, "bg": 1052688}, "off": 0, "kids": {$: "Con", "head": {$: "Link", "st": ($plain$()), "s": "docs", "on_click": {$: "Focus", "elem": 7}}, "tail": {$: "Con", "head": {$: "Input", "st": ($plain$()), "text": "type here", "focused": false, "on_click": {$: "Focus", "elem": 8}}, "tail": {$: "Con", "head": {$: "IconButton", "st": ($pad$(4)), "icon": 65280, "on_click": {$: "Inc", "id": 0, "by": 10}}, "tail": {$: "Con", "head": {$: "Canvas", "st": ($plain$()), "w": 32, "h": 32, "seed": 5}, "tail": {$: "Nil"}}}}}}, "tail": {$: "Nil"}}}}}}}}};
}

function $view$k3$(_r_0, _c_0, _on_0) {
  const _a_0 = _r_0["fst"];
  const _e_0 = _r_0["snd"];
  return {$: "Tuple", "fst": _a_0, "snd": ($tree$(_c_0, _on_0, ($ent$v$(_e_0))))};
}

function $view$k2$(_r_0, _c_0) {
  const _a_0 = _r_0["fst"];
  const _e_0 = _r_0["snd"];
  return $view$k3$({$: "Tuple", fst: _a_0, snd: _a_0[2 % _a_0.length]}, _c_0, ($ent$on$(_e_0)));
}

function $view$k1$(_r_0) {
  const _a_0 = _r_0["fst"];
  const _e_0 = _r_0["snd"];
  return $view$k2$({$: "Tuple", fst: _a_0, snd: _a_0[1 % _a_0.length]}, ($ent$n$(_e_0)));
}

function $view$(_s_0) {
  return $view$k1$({$: "Tuple", fst: _s_0, snd: _s_0[0 % _s_0.length]});
}

function $frame$(_r_0) {
  const _a_0 = _r_0["fst"];
  const _n_0 = _r_0["snd"];
  return {$: "Tuple", "fst": _a_0, "snd": ($place$(($measure$({$: "Con", "head": _n_0, "tail": {$: "Nil"}})), ($root_ctx$(800, 600)), 0))};
}

function $apply$(_m_0, _s_0) {
  if (_m_0.$ === "None") {
    return _s_0;
  } else {
    const _msg_0 = _m_0["value"];
    return $update$(_msg_0, _s_0);
  }
}

function $click$(_r_0, _x_0, _y_0) {
  const _a_0 = _r_0["fst"];
  const _ls_0 = _r_0["snd"];
  return $apply$(($find_hit$(($hits$(_ls_0, {$: "Nil"})), _x_0, _y_0)), _a_0);
}

function $run$($0, $1) {
  for (;;) {
    {
      const _evs_0 = $0;
      const _s_0 = $1;
      if (_evs_0.$ === "Nil") {
        return _s_0;
      } else {
        const _t_0 = _evs_0["head"];
        if (_t_0.$ === "Mouse") {
          const _x_0 = _t_0["x"];
          const _y_0 = _t_0["y"];
          const _t_1 = _t_0["down"];
          if (_t_1) {
            const _t_2 = _evs_0["tail"];
            $0 = _t_2;
            $1 = ($click$(($frame$(($view$(_s_0)))), Math.fround(_x_0), Math.fround(_y_0)));
            continue;
          } else {
            const _t_3 = _evs_0["tail"];
            $0 = _t_3;
            $1 = _s_0;
            continue;
          }
        } else {
          const _t_4 = _evs_0["tail"];
          $0 = _t_4;
          $1 = _s_0;
          continue;
        }
      }
    }
  }
}

function $show_r$(_r_0) {
  const _x_0 = _r_0["x"];
  const _y_0 = _r_0["y"];
  const _w_0 = _r_0["w"];
  const _h_0 = _r_0["h"];
  const _x_1 = f32_show(_h_0);
  const _x_2 = (_x_1 + ")");
  const _x_3 = f32_show(_w_0);
  const _x_4 = ("x" + _x_2);
  const _x_5 = (_x_3 + _x_4);
  const _x_6 = f32_show(_y_0);
  const _x_7 = (" " + _x_5);
  const _x_8 = (_x_6 + _x_7);
  const _x_9 = f32_show(_x_0);
  const _x_10 = ("," + _x_8);
  const _x_11 = (_x_9 + _x_10);
  return ("(" + _x_11);
}

function $show_m$(_m_0) {
  if (_m_0.$ === "None") {
    return "";
  } else {
    const _t_0 = _m_0["value"];
    if (_t_0.$ === "Inc") {
      const _i_0 = _t_0["id"];
      const _by_0 = _t_0["by"];
      const _x_0 = ($U32$show$(_by_0));
      const _x_1 = (_x_0 + ")");
      const _x_2 = ($U32$show$(_i_0));
      const _x_3 = ("," + _x_1);
      const _x_4 = (_x_2 + _x_3);
      return (" on_click=Inc(" + _x_4);
    } else if (_t_0.$ === "Dec") {
      const _i_1 = _t_0["id"];
      const _x_5 = ($U32$show$(_i_1));
      const _x_6 = (_x_5 + ")");
      return (" on_click=Dec(" + _x_6);
    } else if (_t_0.$ === "Reset") {
      const _i_2 = _t_0["id"];
      const _x_7 = ($U32$show$(_i_2));
      const _x_8 = (_x_7 + ")");
      return (" on_click=Reset(" + _x_8);
    } else if (_t_0.$ === "Toggle") {
      const _i_3 = _t_0["id"];
      const _x_9 = ($U32$show$(_i_3));
      const _x_10 = (_x_9 + ")");
      return (" on_click=Toggle(" + _x_10);
    } else if (_t_0.$ === "SetLevel") {
      const _i_4 = _t_0["id"];
      const _x_11 = ($U32$show$(_i_4));
      const _x_12 = (_x_11 + ")");
      return (" on_click=SetLevel(" + _x_12);
    } else {
      const _el_0 = _t_0["elem"];
      const _x_13 = ($U32$show$(_el_0));
      const _x_14 = (_x_13 + ")");
      return (" on_click=Focus(" + _x_14);
    }
  }
}

function $show_p$(_p_0) {
  if (_p_0.$ === "PText") {
    const _s_0 = _p_0["s"];
    return (" text=" + _s_0);
  } else if (_p_0.$ === "PBar") {
    const _v_0 = _p_0["v"];
    const _x_0 = f32_show(_v_0);
    return (" bar=" + _x_0);
  } else {
    return "";
  }
}

function $dump$(_ls_0, _ind_0) {
  if (_ls_0.$ === "Nil") {
    return "";
  } else {
    const _t_0 = _ls_0["head"];
    const _r_0 = _t_0["r"];
    const _p_0 = _t_0["paint"];
    const _h_0 = _t_0["hit"];
    const _kids_0 = _t_0["kids"];
    const _t_1 = _ls_0["tail"];
    const _x_0 = ($dump$(_kids_0, (_ind_0 + "  ")));
    const _x_1 = ($dump$(_t_1, _ind_0));
    const _x_2 = (_x_0 + _x_1);
    const _x_3 = ($show_m$(_h_0));
    const _x_4 = ("\n" + _x_2);
    const _x_5 = ($show_p$(_p_0));
    const _x_6 = (_x_3 + _x_4);
    const _x_7 = ($show_r$(_r_0));
    const _x_8 = (_x_5 + _x_6);
    const _x_9 = (_x_7 + _x_8);
    return (_ind_0 + _x_9);
  }
}

function $report$k$(_r_0) {
  const _ls_0 = _r_0["snd"];
  return $dump$(_ls_0, "");
}

function $state$k3$(_r_0, _s_0) {
  const _e_0 = _r_0["snd"];
  const _x_0 = ($ent$v$(_e_0));
  const _x_1 = f32_show(_x_0);
  const _x_2 = (" level=" + _x_1);
  return (_s_0 + _x_2);
}

function $state$k2$(_r_0, _s_0) {
  const _a_0 = _r_0["fst"];
  const _e_0 = _r_0["snd"];
  const _x_0 = ($Bool$show$(($ent$on$(_e_0))));
  const _x_1 = (" check=" + _x_0);
  return $state$k3$({$: "Tuple", fst: _a_0, snd: _a_0[2 % _a_0.length]}, (_s_0 + _x_1));
}

function $state$k1$(_r_0) {
  const _a_0 = _r_0["fst"];
  const _e_0 = _r_0["snd"];
  const _x_0 = ($U32$show$(($ent$n$(_e_0))));
  return $state$k2$({$: "Tuple", fst: _a_0, snd: _a_0[1 % _a_0.length]}, ("counter=" + _x_0));
}

function $state$(_s_0) {
  return $state$k1$({$: "Tuple", fst: _s_0, snd: _s_0[0 % _s_0.length]});
}

function $store0$() {
  const _x_0 = {$: "Free"};
  const _x_1 = array_new(2, _x_0);
  const _x_2 = {$: "Counter", "n": 0};
  const _x_3 = (_x_1[0 % _x_1.length] = _x_2, _x_1);
  const _x_4 = {$: "Check", "on": false};
  const _x_5 = (_x_3[1 % _x_3.length] = _x_4, _x_3);
  const _x_6 = {$: "Level", "v": 0.25};
  return (_x_5[2 % _x_5.length] = _x_6, _x_5);
}

function $show_u$(_m_0) {
  if (_m_0.$ === "None") {
    return "none";
  } else {
    const _v_0 = _m_0["value"];
    return $U32$show$(_v_0);
  }
}

function $imap_demo$() {
  const _m_0 = ($IMap$put$(32, ($IMap$put$(32, ($IMap$put$(32, {$: "ITip"}, 0, 7, 70)), 0, 8, 80)), 0, 4294967295, 99));
  const _x_0 = ($show_u$(($IMap$get$(32, _m_0, 0, 9))));
  const _x_1 = ($show_u$(($IMap$get$(32, _m_0, 0, 4294967295))));
  const _x_2 = (" 9->" + _x_0);
  const _x_3 = (_x_1 + _x_2);
  const _x_4 = ($show_u$(($IMap$get$(32, _m_0, 0, 8))));
  const _x_5 = (" max->" + _x_3);
  const _x_6 = (_x_4 + _x_5);
  const _x_7 = ($show_u$(($IMap$get$(32, _m_0, 0, 7))));
  const _x_8 = (" 8->" + _x_6);
  const _x_9 = (_x_7 + _x_8);
  return ("imap 7->" + _x_9);
}

function $clicks$() {
  return {$: "Con", "head": {$: "Mouse", "x": 80, "y": 70, "button": 0, "down": true}, "tail": {$: "Con", "head": {$: "Mouse", "x": 80, "y": 70, "button": 0, "down": false}, "tail": {$: "Con", "head": {$: "Mouse", "x": 80, "y": 70, "button": 0, "down": true}, "tail": {$: "Con", "head": {$: "Move", "x": 300, "y": 300}, "tail": {$: "Con", "head": {$: "Mouse", "x": 80, "y": 70, "button": 0, "down": true}, "tail": {$: "Con", "head": {$: "Mouse", "x": 25, "y": 70, "button": 0, "down": true}, "tail": {$: "Con", "head": {$: "Mouse", "x": 720, "y": 270, "button": 0, "down": true}, "tail": {$: "Con", "head": {$: "Mouse", "x": 25, "y": 110, "button": 0, "down": true}, "tail": {$: "Con", "head": {$: "Mouse", "x": 50, "y": 145, "button": 0, "down": true}, "tail": {$: "Con", "head": {$: "Mouse", "x": 400, "y": 500, "button": 0, "down": true}, "tail": {$: "Con", "head": {$: "Mouse", "x": 510, "y": 270, "button": 0, "down": true}, "tail": {$: "Nil"}}}}}}}}}}}};
}

function $layout_of$(_s_0) {
  return $report$k$(($frame$(($view$(_s_0)))));
}

function $after$() {
  return $run$(($clicks$()), ($store0$()));
}

function $final$k$(_r_0) {
  const _a_0 = _r_0["fst"];
  const _b_0 = _r_0["snd"];
  const _x_0 = ($layout_of$(_b_0));
  const _x_1 = ($state$(_a_0));
  const _x_2 = ("\n" + _x_0);
  return (_x_1 + _x_2);
}

function $F32$from_nat$(_n_0) {
  const _x_0 = (_n_0 >>> 0);
  return Math.fround(_x_0);
}

function $F32$max$(_a_0, _b_0) {
  return $Bool$pick$((_a_0 < _b_0), _b_0, _a_0);
}

function $U32$max$(_a_0, _b_0) {
  return $Bool$pick$((_a_0 < _b_0), _b_0, _a_0);
}

function $U32$show$(_a_0) {
  const _b_0 = _a_0;
  return $U32$show$if$(_b_0, (_b_0 === 0));
}

function $Bool$and$(_a_0, _b_0) {
  if (!_a_0) {
    return false;
  } else {
    return _b_0;
  }
}

function $Bool$not$(_b_0) {
  if (!_b_0) {
    return true;
  } else {
    return false;
  }
}

function $Bool$show$(_b_0) {
  if (!_b_0) {
    return "False";
  } else {
    return "True";
  }
}

function $Bool$pick$(_c_0, _a_0, _b_0) {
  if (!_c_0) {
    return _b_0;
  } else {
    return _a_0;
  }
}

function $U32$show$if$(_a_0, _z_0) {
  if (_z_0) {
    return "0";
  } else {
    return $U32$show$go$(10, _a_0, "");
  }
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
export default {
  "fpick": run_lib((a0, a1, a2) => { const r = (run_loop($fpick$((a0), (a1), (a2)))); (a0); (a1); (a2); return r; }, 3),
  "len_or": run_lib((a0, a1) => { const r = (run_loop($len_or$((a0), (a1)))); (a0); (a1); return r; }, 2),
  "main_of": run_lib((a0, a1, a2) => { const r = (run_loop($main_of$((a0), (a1), (a2)))); (a0); (a1); (a2); return r; }, 3),
  "cross_of": run_lib((a0, a1, a2) => { const r = (run_loop($cross_of$((a0), (a1), (a2)))); (a0); (a1); (a2); return r; }, 3),
  "text_w": run_lib((a0, a1) => { const r = (run_loop($text_w$((a0), (a1)))); (a0); (a1); return r; }, 2),
  "style": run_lib((a0, a1, a2, a3, a4, a5, a6) => { const r = (run_loop($style$((a0), (a1), (a2), (a3), (a4), (a5), (a6)))); (a0); (a1); (a2); (a3); (a4); (a5); (a6); return r; }, 7),
  "plain": run_lib(() => { const r = (run_loop($plain$()));  return r; }, 0),
  "grow_of": run_lib((a0) => { const r = (run_loop($grow_of$((a0)))); (a0); return r; }, 1),
  "tot": run_lib((a0, a1, a2) => { const r = (run_loop($tot$((a0), (a1), (a2)))); (a0); (a1); (a2); return r; }, 3),
  "stack_wh": run_lib((a0, a1, a2) => { const r = (run_loop($stack_wh$((a0), (a1), (a2)))); (a0); (a1); (a2); return r; }, 3),
  "gaps": run_lib((a0, a1) => { const r = (run_loop($gaps$((a0), (a1)))); (a0); (a1); return r; }, 2),
  "flow_box.k": run_lib((a0, a1, a2, a3, a4) => { const r = (run_loop($flow_box$k$((a0), (a1), (a2), (a3), (a4)))); (a0); (a1); (a2); (a3); (a4); return r; }, 5),
  "axis_of": run_lib((a0) => { const r = (run_loop($axis_of$((a0)))); (a0); return r; }, 1),
  "flow_box": run_lib((a0, a1, a2, a3) => { const r = (run_loop($flow_box$((a0), (a1), (a2), (a3)))); (a0); (a1); (a2); (a3); return r; }, 4),
  "stack_box.k": run_lib((a0, a1, a2) => { const r = (run_loop($stack_box$k$((a0), (a1), (a2)))); (a0); (a1); (a2); return r; }, 3),
  "stack_box": run_lib((a0, a1) => { const r = (run_loop($stack_box$((a0), (a1)))); (a0); (a1); return r; }, 2),
  "leaf": run_lib((a0, a1, a2, a3, a4) => { const r = (run_loop($leaf$((a0), (a1), (a2), (a3), (a4)))); (a0); (a1); (a2); (a3); (a4); return r; }, 5),
  "bg_of": run_lib((a0) => { const r = (run_loop($bg_of$((a0)))); (a0); return r; }, 1),
  "measure": run_lib((a0) => { const r = (run_loop($measure$((a0)))); (a0); return r; }, 1),
  "align_off": run_lib((a0, a1) => { const r = (run_loop($align_off$((a0), (a1)))); (a0); (a1); return r; }, 2),
  "is_stretch": run_lib((a0) => { const r = (run_loop($is_stretch$((a0)))); (a0); return r; }, 1),
  "kid_rect.fin": run_lib((a0, a1, a2, a3, a4, a5, a6, a7, a8, a9) => { const r = (run_loop($kid_rect$fin$((a0), (a1), (a2), (a3), (a4), (a5), (a6), (a7), (a8), (a9)))); (a0); (a1); (a2); (a3); (a4); (a5); (a6); (a7); (a8); (a9); return r; }, 10),
  "kid_rect": run_lib((a0, a1, a2, a3, a4) => { const r = (run_loop($kid_rect$((a0), (a1), (a2), (a3), (a4)))); (a0); (a1); (a2); (a3); (a4); return r; }, 5),
  "next_cur": run_lib((a0, a1, a2) => { const r = (run_loop($next_cur$((a0), (a1), (a2)))); (a0); (a1); (a2); return r; }, 3),
  "justify": run_lib((a0, a1, a2, a3, a4) => { const r = (run_loop($justify$((a0), (a1), (a2), (a3), (a4)))); (a0); (a1); (a2); (a3); (a4); return r; }, 5),
  "enter.fin": run_lib((a0, a1, a2, a3, a4, a5, a6, a7, a8) => { const r = (run_loop($enter$fin$((a0), (a1), (a2), (a3), (a4), (a5), (a6), (a7), (a8)))); (a0); (a1); (a2); (a3); (a4); (a5); (a6); (a7); (a8); return r; }, 9),
  "enter.k": run_lib((a0, a1, a2, a3) => { const r = (run_loop($enter$k$((a0), (a1), (a2), (a3)))); (a0); (a1); (a2); (a3); return r; }, 4),
  "enter": run_lib((a0, a1, a2, a3) => { const r = (run_loop($enter$((a0), (a1), (a2), (a3)))); (a0); (a1); (a2); (a3); return r; }, 4),
  "ctx_start": run_lib((a0) => { const r = (run_loop($ctx_start$((a0)))); (a0); return r; }, 1),
  "place": run_lib((a0, a1, a2) => { const r = (run_loop($place$((a0), (a1), (a2)))); (a0); (a1); (a2); return r; }, 3),
  "root_ctx": run_lib((a0, a1) => { const r = (run_loop($root_ctx$((a0), (a1)))); (a0); (a1); return r; }, 2),
  "hits": run_lib((a0, a1) => { const r = (run_loop($hits$((a0), (a1)))); (a0); (a1); return r; }, 2),
  "inside": run_lib((a0, a1, a2) => { const r = (run_loop($inside$((a0), (a1), (a2)))); (a0); (a1); (a2); return r; }, 3),
  "find_hit.k": run_lib((a0, a1, a2) => { const r = (run_loop($find_hit$k$((a0), (a1), (a2)))); (a0); (a1); (a2); return r; }, 3),
  "find_hit": run_lib((a0, a1, a2) => { const r = (run_loop($find_hit$((a0), (a1), (a2)))); (a0); (a1); (a2); return r; }, 3),
  "upick": run_lib((a0, a1, a2) => { const r = (run_loop($upick$((a0), (a1), (a2)))); (a0); (a1); (a2); return r; }, 3),
  "ent.inc": run_lib((a0, a1) => { const r = (run_loop($ent$inc$((a0), (a1)))); (a0); (a1); return r; }, 2),
  "ent.dec": run_lib((a0) => { const r = (run_loop($ent$dec$((a0)))); (a0); return r; }, 1),
  "ent.toggle": run_lib((a0) => { const r = (run_loop($ent$toggle$((a0)))); (a0); return r; }, 1),
  "ent.reset": run_lib((a0) => { const r = (run_loop($ent$reset$((a0)))); (a0); return r; }, 1),
  "ent.level": run_lib((a0, a1) => { const r = (run_loop($ent$level$((a0), (a1)))); (a0); (a1); return r; }, 2),
  "ent.apply": run_lib((a0, a1) => { const r = (run_loop($ent$apply$((a0), (a1)))); (a0); (a1); return r; }, 2),
  "msg_id": run_lib((a0) => { const r = (run_loop($msg_id$((a0)))); (a0); return r; }, 1),
  "store.with": run_lib((a0, a1, a2) => { const r = (run_loop($store$with$((a0), (a1), (a2)))); (a0); (a1); (a2); return r; }, 3),
  "update": run_lib((a0, a1) => { const r = (run_loop($update$((a0), (a1)))); (a0); (a1); return r; }, 2),
  "ent.n": run_lib((a0) => { const r = (run_loop($ent$n$((a0)))); (a0); return r; }, 1),
  "ent.on": run_lib((a0) => { const r = (run_loop($ent$on$((a0)))); (a0); return r; }, 1),
  "ent.v": run_lib((a0) => { const r = (run_loop($ent$v$((a0)))); (a0); return r; }, 1),
  "IMap.bit": run_lib((a0, a1) => { const r = (run_loop($IMap$bit$((a0), nat_host(a1)))); (a0); BigInt(a1); return r; }, 2),
  "IMap.pick": run_lib((a0, a1, a2) => { const r = (run_loop($IMap$pick$((a0), (a1), (a2)))); (a0); (a1); (a2); return r; }, 3),
  "IMap.node": run_lib((a0, a1, a2, a3) => { const r = (run_loop($IMap$node$((a0), (a1), (a2), (a3)))); (a0); (a1); (a2); (a3); return r; }, 4),
  "IMap.leaf_or": run_lib((a0, a1, a2) => { const r = (run_loop($IMap$leaf_or$((a0), (a1), (a2)))); (a0); (a1); (a2); return r; }, 3),
  "IMap.put": run_lib((a0, a1, a2, a3, a4) => { const r = (run_loop($IMap$put$(nat_host(a0), (a1), nat_host(a2), (a3), (a4)))); BigInt(a0); (a1); BigInt(a2); (a3); (a4); return r; }, 5),
  "IMap.hit": run_lib((a0, a1) => { const r = (run_loop($IMap$hit$((a0), (a1)))); (a0); (a1); return r; }, 2),
  "IMap.get": run_lib((a0, a1, a2, a3) => { const r = (run_loop($IMap$get$(nat_host(a0), (a1), nat_host(a2), (a3)))); BigInt(a0); (a1); BigInt(a2); (a3); return r; }, 4),
  "pad": run_lib((a0) => { const r = (run_loop($pad$((a0)))); (a0); return r; }, 1),
  "row": run_lib((a0, a1, a2) => { const r = (run_loop($row$((a0), (a1), (a2)))); (a0); (a1); (a2); return r; }, 3),
  "grow1": run_lib(() => { const r = (run_loop($grow1$()));  return r; }, 0),
  "tree": run_lib((a0, a1, a2) => { const r = (run_loop($tree$((a0), (a1), (a2)))); (a0); (a1); (a2); return r; }, 3),
  "view.k3": run_lib((a0, a1, a2) => { const r = (run_loop($view$k3$((a0), (a1), (a2)))); (a0); (a1); (a2); return r; }, 3),
  "view.k2": run_lib((a0, a1) => { const r = (run_loop($view$k2$((a0), (a1)))); (a0); (a1); return r; }, 2),
  "view.k1": run_lib((a0) => { const r = (run_loop($view$k1$((a0)))); (a0); return r; }, 1),
  "view": run_lib((a0) => { const r = (run_loop($view$((a0)))); (a0); return r; }, 1),
  "frame": run_lib((a0) => { const r = (run_loop($frame$((a0)))); (a0); return r; }, 1),
  "apply": run_lib((a0, a1) => { const r = (run_loop($apply$((a0), (a1)))); (a0); (a1); return r; }, 2),
  "click": run_lib((a0, a1, a2) => { const r = (run_loop($click$((a0), (a1), (a2)))); (a0); (a1); (a2); return r; }, 3),
  "run": run_lib((a0, a1) => { const r = (run_loop($run$((a0), (a1)))); (a0); (a1); return r; }, 2),
  "show_r": run_lib((a0) => { const r = (run_loop($show_r$((a0)))); (a0); return r; }, 1),
  "show_m": run_lib((a0) => { const r = (run_loop($show_m$((a0)))); (a0); return r; }, 1),
  "show_p": run_lib((a0) => { const r = (run_loop($show_p$((a0)))); (a0); return r; }, 1),
  "dump": run_lib((a0, a1) => { const r = (run_loop($dump$((a0), (a1)))); (a0); (a1); return r; }, 2),
  "report.k": run_lib((a0) => { const r = (run_loop($report$k$((a0)))); (a0); return r; }, 1),
  "state.k3": run_lib((a0, a1) => { const r = (run_loop($state$k3$((a0), (a1)))); (a0); (a1); return r; }, 2),
  "state.k2": run_lib((a0, a1) => { const r = (run_loop($state$k2$((a0), (a1)))); (a0); (a1); return r; }, 2),
  "state.k1": run_lib((a0) => { const r = (run_loop($state$k1$((a0)))); (a0); return r; }, 1),
  "state": run_lib((a0) => { const r = (run_loop($state$((a0)))); (a0); return r; }, 1),
  "store0": run_lib(() => { const r = (run_loop($store0$()));  return r; }, 0),
  "show_u": run_lib((a0) => { const r = (run_loop($show_u$((a0)))); (a0); return r; }, 1),
  "imap_demo": run_lib(() => { const r = (run_loop($imap_demo$()));  return r; }, 0),
  "clicks": run_lib(() => { const r = (run_loop($clicks$()));  return r; }, 0),
  "layout_of": run_lib((a0) => { const r = (run_loop($layout_of$((a0)))); (a0); return r; }, 1),
  "after": run_lib(() => { const r = (run_loop($after$()));  return r; }, 0),
  "final.k": run_lib((a0) => { const r = (run_loop($final$k$((a0)))); (a0); return r; }, 1),
};
