# Gap-fill results: zui written in Bend 2 (M3 Pro, macOS 27.0.1, Bend 565d7fd)

Bend was upstream HEAD `565d7fd` when I started and still was at the end (`git fetch --depth 1` showed no new commit). Everything ran on the M3 Pro (6 performance + 6 efficiency cores, on AC power). Other processes kept the load average at 3–12 the whole time: PerfPowerServices used about 140% CPU, plus WindowServer, Music, Maestro and Codex. That noise affects every timing, so I alternated rounds and quote medians of per-run medians.

All work is in `research/v/gapfill`, written `G/` below. `G/build.sh dir/name` builds a program; run scripts and stats scripts sit next to each program.

**What changes in the verdict:**
- **Framework logic in Bend holds.** The core is cheap on the CPU.
- **The "120 Hz with the CPU pool" claim does not carry over to Retina.** A full redraw at 2x runs at about 60 Hz, and keeping 120 Hz needs damage tracking.
- **The ranking flips to P3.** A small native Metal shader drawing the Bend-built Scene in place is 12–35x faster than any P2 variant and holds 120 Hz at 2x. The report has to say plainly that MSL shades the pixels, not Bend.
- **The allocator slowdown is real but scale-dependent.** It is not a killer for a UI that rebuilds only a few thousand chars per frame.

## Gap 1: per-frame cost of the framework core

**What I built.** `G/core/core_lib.bend` extends `sketch/ui.bend` with:
- a real greedy word wrap over per-char advances, producing a positioned glyph run per text node (`wword`/`wrap`, lines 159 and 187);
- the ScrollView offset;
- a paint pass that emits a flat Scene (quads plus glyph sprites) and the hitbox list (`paint`/`emit`, lines 464 and 475);
- hit test and dispatch (`find_hit`, line 497).

The view (line 538) is a scrolling list of rows, each a Row holding Text (about 65 chars, wrapped at 300 px), Spacer and Button. Each frame changes the text through `U32.show` and moves the scroll offset, so nothing is cached. The frame driver is `core_main.bend`; `run_core.sh` and `run_core_nb.sh` run the matrix and `cstats.py` summarises it.

**Results.** 3 runs x 100 frames each (the first 10 frames dropped). Load during these runs was 4.4–5.4.

| elements (rows) | glyphs wrapped and emitted | view | layout (measure + wrap + place) | paint | hit | whole core, one expression: median (range of run medians) |
|---|---|---|---|---|---|---|
| 501 (125) | 7,752 | 0.036 ms | 0.078 ms | 0.055 ms | 0.001 ms | --gpu off 0.171 (0.171–0.172); default lane 0.171 (0.169–0.187); 1 thread 0.173 |
| 2,001 (500) | 31,735 | 0.207 ms | 0.385 ms | 0.214 ms | 0.005 ms | --gpu off 0.810 (0.804–0.823); default 0.803 (0.799–0.814); 1 thread 0.875 |
| 5,001 (1,250) | 79,985 | 0.550 ms | 1.014 ms | 0.588 ms | 0.014 ms | --gpu off 2.14 (2.10–2.17), p90 2.34; default 2.15 (2.12–2.20); 1 thread 2.26 |

- **No parallel speedup.** The code is sequential recursion over lists, so 1 thread and 12 threads give the same times.
- **"Default lane" needed a bang-free build.** `core_nb` is the same program with no `!` in it; the default-lane numbers above come from it.
- **Laying out on the `!` lane is not usable.** `layout!` took 14.4 ms at 501 elements, and the whole core under one `!` took 30.1 ms (1 run x 20 frames).
- **Even the non-bang path went to the GPU.** In the binary that also contains `layout!`, the arm that calls `layout(...)` without `!` still ran on the GPU: 16.6 ms at 501 elements.
  - At 2,001 and 5,001 elements every one of those runs died with `bend: memory fault (machine stack overflow?)`, both the bang and non-bang paths (`G/core/mx/*-default-*_r*.err`, `staged-layoutbang-*`, `one-bang-*`).
  - The cause is that the bang flag belongs to the def, not the call site: `comp.ts:1376-1377` adds the callee to `fl.bangs`, `comp.ts:2836` writes `FID_T`, and `comp.ts:5260` sends any root task of a bang-marked def to the GPU.

**CoreText round trip.** Effect: `G/ct/shape.c:19`, using `CTTypesetterSuggestLineBreak`. Driver: `G/ct/ct.bend`. It goes String → UTF-8 → CFString → line breaks → glyph id, x, line and advance → `List<&2, U32>` → decoded into a Bend `Run`. 3 runs x 100 iterations:
- **Whole 2,000 chars in one call, wrapped into 24 lines:** 0.363 ms median (range 0.336–0.57).
  - CoreText itself is 330 µs of that. Turning the String into UTF-8 is 5.5 µs, building the list 9.9 µs, and decoding in Bend about 15 µs.
  - The first call costs 9 ms (font setup).
- **25 separate 80-char lines:** 0.253 ms total (range 0.235–0.441), about 10 µs per changed line.

**Verdict.** "Framework logic can be pure Bend" holds, and a tree of 2,000–5,000 elements does not by itself force retained layout or view caching. But at 1x the full-redraw raster already uses 7.5–8.3 ms, so adding 0.8–2.3 ms of core pushes P2's 1x full redraw past 8.33 ms. Holding 120 Hz needs damage tracking (Gap 2) or P3 (Gap 3) in any case.

## Gap 2: Retina (2x) with a realistic redraw policy

**What I built.** `G/dirty/main_dirty.bend`, starting from `ui_common`, at 3024x1964 with 256 cards and 2,000 glyphs of 16x32 px and 8-bit coverage. The incremental update (`upd`, line 25) keeps the previous frame's Image tree. It re-rasterizes only the 128-px cells that touch the dirty rectangle and moves every other subtree over unchanged.

I tried two ways of storing glyph texels:
- **tree:** a shared, refcounted atlas tree, which is the safe-Bend option (`glyph2x.bend:45`);
- **hash:** texels computed per pixel from a hash, which stands in for an atlas resident in L1 cache and is a lower bound (`glyph2x_proc.bend`).

**Correctness.** In every scenario the incremental image hashes to exactly the same value as a full redraw (`check incremental_blit_sum … equal True`).

**Headless, CPU pool, 3 runs x 37 frames** (`run_dirty.sh`, `dstats.py`, load 5.2–9.1). Times are full-frame medians, with the range of run medians.

| scenario (dirty pixels) | hash texels | tree texels |
|---|---|---|
| full redraw | 15.1–15.4 ms (render 12.2) | 62.4 ms |
| incremental, nothing changed | 0.85 ms | 1.07 ms |
| incremental, caret blink (351 px) | 1.50 ms (1.45–3.45) | 3.73 ms |
| incremental, hover on one card (23,684 px) | 2.36 ms (2.02–3.99) | 4.69 ms |
| incremental, one scrolling text column (398,692 px) | 7.96 ms (6.71–8.25) | 23.6 ms |
| incremental, everything moves | 15.8 ms | 63.7 ms |

- **The incremental path is not a GPU job.** On the default (GPU) lane it took 52–106 ms per frame.
- **The tree atlas is pathological on the GPU.** A full redraw on the default lane did not finish one frame in more than 5 minutes; I killed it.
- **The tree atlas also scales poorly on the CPU.** With 1 thread vs 12 it is 210 vs 57 ms per frame, which points to refcount traffic on the shared atlas.

**Real window at 2x.** I used the PR #1108 window code, which gives a 1512x982-point window with a 3024x1964 drawable (`G/run_win.sh`, `G/winstats.py`). 3 runs x 115 frames, load 6.2–11.6.

| variant | frame median | frames over 12.5 ms (missed a 120 Hz frame) |
|---|---|---|
| full redraw, hash | 16.87 ms | 100% |
| full redraw, tree | 63.9 ms | 100% |
| incremental, nothing changed / hover / caret, hash | 8.33–8.36 ms | 1–2% |
| incremental, text column, hash | 8.38 ms | 4% |
| incremental, hover / caret, tree | 8.34–8.36 ms | 1–2% |
| incremental, text column, tree | 24.9 ms | 100% (41% also over 25 ms, missing 60 Hz) |

**Verdict.** It changes. P2 is smooth at 2x only with damage tracking, which is a retained-image design with invalidation, and only for small damage. Full-screen changes (resize, theme switch, scrolling a large pane) run at 60 Hz or below. Correct antialiased 8-bit glyphs stored in a safe shared structure are 4x the cost of the 1x numbers.

## Gap 3: the P3 prototype, Bend Scene drawn by native Metal

**What I built.** `G/p3/p3fx.c`. The host walks the Bend `Qs` and `Gs` lists once (`p3_walk`, line 193) and writes only each node's heap offset, 4 bytes per primitive. The shaders then read every field straight out of the Bend heap:
- **mode 0, render pipeline:** instanced quads and glyphs, a rounded-rect SDF with border in the fragment shader, and the blend hardware (`quad_vs`/`quad_fs`, lines 74 and 81);
- **modes 1 and 2, compute kernel per pixel with no binning** (line 102).

When the GPU is on, it uses `gpu_dev`, `gpu_que` and `gpu_buf` from the bang runtime (line 129).

**Validation.** Its output matches Bend's own rasterizer (bin mode, presented with Blit) within 1 colour step on 100% of pixels, with 95.2% exact. That holds at both resolutions, on both executors, and with mode 2 (`cmp.py`). With a Bend raster bang, a Blit present and `Image.drop!` in the same frame before P3, sharing works and the GPU time stays the same: 0.142 ms at 1920x1200 and 0.343 ms at 3024x1964.

**Headless timing.** `run_p3.sh` and `p3stats.py`, 3 runs x 97 frames, load about 3.3–3.7 for the runs whose log lines I captured. N=256 cards and 2,000 glyphs.

| | GPU time | effect wall time | whole frame (build + draw + drop) | earlier P2 rows (frame) |
|---|---|---|---|---|
| 1920x1200 | 0.143–0.146 ms | 0.37–0.42 ms | 0.42–0.47 ms | bin-cpu12 8.34, bin-gpu 7.84 ms |
| 3024x1964 | 0.342 ms | 0.57–0.65 ms | 0.62–0.71 ms | bin-cpu12 16.48, bin-gpu 24.22 ms |

- The list walk costs 8–12 µs and encoding about 6 µs. N=1024 gives the same times.
- **A per-pixel compute kernel is not viable without binning.** Quads only: 3.4 ms (1920x1200) and 7.7 ms (3024x1964) at N=256, 16 and 35 ms at N=1024. With glyphs: 34–113 ms.
- **In a real 2x window** (`p3win`, `P3.present` into the window's CAMetalLayer drawable): 8.26 ms median, locked to vsync, with 0% of frames over 12.5 ms (3 runs x 115 frames).
  - The GPU time there is 2.55 ms against 0.34 ms headless. I did not find out why; it still fits the budget.

**Verdict.** It changes. P3 (Bend logic plus a raster pipeline of about 60 lines of MSL) beats both P2 variants by 12–35x and holds 120 Hz at 2x with a full redraw, so no damage tracking is needed. With the Gap 1 core (0.2–2.3 ms) the end-to-end frame stays well under 8.3 ms. The verdict must say the pixels are not shaded by Bend code. Bend device code is not competitive: 7.8–24 ms for a full frame, and 52–106 ms for incremental updates on `!`.

## Gap 4: allocator degradation on the right workload

**What I built.** `G/drift/main_drift4.bend` adds two things per frame to the cull-cpu12 loop:
- about 2,000 chars of text built with String concatenation and `U32.show` of the frame counter, then consumed as the frame's glyph sprites (`tcell`/`tsprites`);
- a 200-entry `Map<String, U32>` of element state, rebuilt each frame from the previous frame's map (`estate`).

`drift4b` also allocates 4,096 records per frame shaped like the #1307 repro (an `Item{Blob{U32, Array}}` list) and lets them drop automatically. Each ran 20,000 frames headless with `--gpu off`. Each is compared with the first 1,000 frames after frame 5 against the last 1,000.

| run | frame median, first → last | component medians, first → last | memory (RSS) | load |
|---|---|---|---|---|
| drift4 | 8.89 → 8.67 ms (0.97x) | map 0.633 → 0.672 ms (+6%); text 0.177 → 0.149 ms | flat at about 38–40 MB | 4.0–8.9 |
| drift4b | 8.96 → 8.69 ms | wrapped-array step 0.135 → 0.193 ms (+43%, rising in each 2,000-frame block) | 40.2 → 40.8 MB | 6.7–12.2 |
| control (numeric scene, same machine state) | 7.94 → 8.38 ms (+6%, rises and falls) | — | — | 8.0–12.0 |

Upstream repros at HEAD `565d7fd` on this Mac:
- **#1007** (`G/i1007/repro1007`): 1 thread 68 → 185 ms per round (2.7x); 4 threads 31 → 505 (16x); 12 threads 24 → 433 (18x). It reproduces.
- **#1307:** only mild. Build grew from 4–8 to 10–16 ms and dispose from 11 to about 20 ms, not the 30–50x the issue reports.

To find where #1007 starts, I scaled its text volume (12 threads):

| chars per round | rounds | growth |
|---|---|---|
| 160K | 600 | 4 → 5 ms (+25%) |
| 329K | 400 | 3 → 11 ms (3.7x) |
| 688K | 200 | 6 → 27 ms (4.5x) |
| 3M | 24 | 18x |

**Verdict.** The slowdown is a working-set effect. It starts once per-frame String churn reaches a few MB, and a UI rebuilding about 2,000 chars and 200 String keys per frame shows no slowdown over 20,000 frames. For P2/P3's UI pattern it is not a killer and does not need backplane-style child-process workarounds. It would hit a text-heavy app that rebuilds large Strings every frame, such as an editor buffer, so the design must cache text per line. The small rising cost of the wrapped-array step, and anything beyond 20,000 frames (about 3 minutes at 120 Hz), are not measured; the load confound remains.