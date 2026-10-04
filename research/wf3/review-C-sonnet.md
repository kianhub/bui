## Findings

### 1. [critical] "Held 120 Hz, no missed frames" is overstated, and the 2.55 ms GPU figure is cherry-picked from a noisy distribution
**Location**: `wf2/explanation.md:8,107`, `wf2/gapfill.md` (Gap 3, "In a real 2x window"), `v/gapfill/winstats.py`, `v/gapfill/win/p3w_r{1,2,3}.{err,out}`
**Finding**: Three claims here do not follow from the data. The first is "0% of frames over 12.5 ms". The second is that the in-window GPU time is "2.55 ms vs 0.34 ms headless". The third is that the frame "held 120 Hz".
**Evidence**: I recomputed from the raw logs, dropping the first 5 frames as `winstats.py` does.
- **Missed frames:** run 1 has a 13.99 ms frame, which is over 12.5 ms. That is 1 of 115 frames, so the "0%" does not hold.
- **Near misses:** 15, 16 and 15 frames per run, about 13%, exceed 9 ms.
- **GPU time per run:** the run medians are 1.75, 2.93 and 2.55 ms. The reported 2.55 is run 3 only.
- **Spread:** within a run the GPU time ranges from 0.44 to 5.5 ms. The minimum matches headless, so this is not a constant 7x penalty. It looks like clock state or contention. The machine was at load 6-12 with 35-65% external GPU use, and the GPU idles about 6 of every 8.3 ms. Compositor or drawable stalls, and DVFS ramp-down when the GPU idles between vsyncs, are both consistent with this pattern. Neither was tested.
- **No presentation measurement:** "frame_us" is a CPU-side `t2-t0` taken around a call that blocks in `nextDrawable`. The median of 8.26 ms is the vsync cap, so it says nothing about headroom. The code never uses `addPresentedHandler` or `presentedTime`, so it cannot count missed vsyncs.
- **Headroom:** with `waitUntilCompleted`, CPU work and GPU work run in series. A 5.5 ms GPU outlier plus the 2.15 ms core is already 7.7 ms of an 8.33 ms budget. That is before walk, encode and glyph-heavy scenes. "Well under 8.3 ms" does not hold.
**Suggestion**: Report GPU time as a distribution (p50, p90, max) across all runs. Measure missed vsyncs with presentation timestamps. Run the window test while the core is running. Test the DVFS hypothesis by holding the GPU busy, for example with a dummy kernel.

### 2. [critical] The P3 and core numbers were never measured together, and the scene scales differ by 40x
**Location**: `explanation.md:107,112` ("Estimated total with a 5k-element core: about 3 ms"), `core_lib.bend` `emit`/`Ss`, `p3/ui_common.bend` `sprite.mk`/`GCons`, `p3fx.c:176`
**Finding**: The renderer and the core feed different scene formats, and the end-to-end figure is a sum of separate parts at mismatched sizes.
- **Scene format:** the core emits `SpCon{x,y,c,...}` sprites with a char code. P3 reads `GCons` nodes of 19 words, with 16 inline rows of 4-bit texels, produced by a synthetic generator (`atlas()`, hash-derived texels, 96 glyphs). P3 never rendered the core's output.
- **Glyph count:** P3 was benchmarked with 2,000 glyphs and N up to 1,024 cards. The core at 5,001 elements emits 79,985 glyphs, about 40x more.
- **Cost at scale:** the walk (about 8-12 µs for 2.3k nodes), the per-instance GPU cost and the inline-row heap churn were never measured at 80k glyphs.
- **Glyph storage:** the real design needs an atlas texture and tile ids, which the explanation concedes is "a production version". The 0.34 ms and 0.42 ms figures therefore measure a toy glyph representation. The scene it draws is 256 cards, which is not representative.
**Suggestion**: Make the core emit P3's format, or the reverse, and run the full chain at 2k and 5k elements in a window.

### 3. [critical] The allocator conclusion was tested at 2,000 chars per frame, but the core it protects emits 8k to 80k per frame
**Location**: `gapfill.md` Gap 1 vs Gap 4, `explanation.md:208`
**Finding**: Gap 4 says a UI rebuilding about 2,000 chars and 200 String keys per frame shows no slowdown. Gap 1's workload builds `rowtext(i,c)` with `++` and `U32.show` for every row, every frame. That is 7,752 glyph chars at 501 elements and 79,985 at 5,001.
**Evidence**:
- Gap 4's own scaling table shows slowdown at 160K chars per round (+25%) and 3.7x at 329K. The core's 5k-element frame is in that range, and the 2k-element frame (31.7k chars) is about 10x below it.
- The core was timed for only 100 frames per run. The 20,000-frame drift test used a 40x lighter text load.
- #1007 also reproduces at 2.7x on a single thread, and the core is single-threaded.
- The verdict relies on both numbers together, but no test combines them.
**Suggestion**: Run the core at 2,001 and 5,001 elements for 20k frames or more, and compare the first and last 1,000 frames.

### 4. [warning] Core timing omits most of the per-frame work the design requires
**Location**: `core_lib.bend:144-150` (`adv`), `core_main.bend:frame.staged`, `explanation.md:87,90`
**Finding**: The 0.17 to 2.15 ms figure is "view + layout + paint + hit", with the work below stubbed or absent.
- **Text metrics:** `adv()` is an arithmetic table over char codes. The design's per-frame shape-cache lookup is missing: a String-keyed Map lookup per text node, hashing and comparing cons-list Strings.
- **Layout and hit testing:** there is no glyph-id or atlas lookup, kerning or font fallback. Layout covers only the flex subset, and the single hit test calls `apply` on a counter Msg.
- **Not timed at all:** the entity store (`Array` slot table, release or sweep), the event drain, the keymap and focus walk, the IME snapshot push, async tasks and timers, subscriptions and notify.
- **Workload shape:** the view is one homogeneous list of identical rows. It has no nesting, no overlays and no uniform_list virtualization.
- **Missing layout features:** the elements are not GPUI's `Style`, which also has grid and block layout.
- **Claim vs measurement:** the verdict's sentence "express... the entity store, message dispatch" rests on the 739-line sketch. That sketch was never timed under load.
**Suggestion**: Label the figure as "the flex subset on a synthetic list with a stubbed metrics table". Add a real shape-cache lookup and an entity update to the timed path.

### 5. [warning] The safety argument for reading the Bend heap in place is misattributed, and it forbids pipelining
**Location**: `explanation.md:94`, `p3fx.c:238-244` (`[cb waitUntilCompleted]`), `p3fx.c:132-147` (`p3_corpus`)
**Finding**: The explanation says "Bend's affine typing keeps the Scene alive while the GPU reads it". What actually prevents a use-after-free is `[cb waitUntilCompleted]` inside the effect. Affine typing only means the lists are handed back after the effect returns.
**Evidence**:
- Every timing therefore includes a full CPU stall for the GPU, and the Bend event loop is blocked for the whole frame.
- `nextDrawable` also blocks inside the effect, which is why `encode_us` is 3.7-6.6 ms in-window. Timers and channels cannot run during that time. The `IO.sleep(0)` seam does not fix this.
- Overlapping CPU frame N+1 with GPU frame N requires double-buffering the Scene or copying it into a packed buffer. That removes the zero-copy advantage, and the "tens of µs" copy is unmeasured (`explanation.md:207`).
- Heap buffer sizing: in the unshared path, `len` is doubled with no check against the mapped region, and the buffer is recreated only on growth. Whether `e.mem` can move or shrink, and whether the buffer can exceed the mapping, was not checked. `newBufferWithBytesNoCopy` also needs page alignment.
- Offsets are stored as `(u32)loc`, and the shader reads fields with no bounds checks.
**Suggestion**: State that the safety comes from a synchronous wait. Prototype and time the packed-copy variant, and decide whether the design is pipelined.

### 6. [warning] The recommended build configuration (BANGS 0, no shared queue) was never run in the window
**Location**: `v/gapfill/p3/p3.c:610` (BANGS 3), `p3win.c:505` (BANGS 1), `p3fx.c:117-128`, `explanation.md:97-98,114`
**Finding**: The verdict recommends "no `!` anywhere, `BANGS 0`, no `.gpu`, own heap wrap". The window result was run with `shared 1`, meaning the bang runtime's `gpu_dev`, `gpu_que` and `gpu_buf`.
**Evidence**:
- Both P3 binaries contain `Image.drop!`. The headless `cpu12` rows use `--gpu off` on a BANGS-3 binary, so they exercise the unshared `p3_heap` path, but not in a BANGS-0 build and not in a window.
- The window test used PR #1108's `window.c`, which is open, 74 commits behind and no longer applies cleanly.
- `core_nb.c` is the only BANGS-0 binary, and it has no P3 in it.
**Suggestion**: Build `p3win` with no bang, using the private queue and the no-copy heap wrap, and re-run the window test.

### 7. [warning] "82% Bend" is a definition applied to lines that mostly do not exist, and "fully written in Bend" is answered as "yes"
**Location**: `explanation.md:3,10,107,279`, skeptic output (premise-estimates)
**Finding**: The percentage is zui lines that would be rewritten (67,358) over (67,358 + 15,183 for `gpui_macos`).
**Evidence**:
- **Measured vs counted:** 67k is a count of Rust to be replaced. It is not Bend code. The sketch plus the core is a few thousand lines, so under about 5% of the 67k is written. The 82% is a scope statement, not progress or a measured share.
- **Numerator inflation:** `gpui/src/platform/` (3,786 lines) contains non-macOS and test code (`layer_shell`, `popup`, `scap_screen_capture`, `bench_dispatcher`, `test`, `visual_test`). It sits in the Bend side.
- **Denominator exclusions:** taffy (22k), lyon (34k), resvg (23k), etagere (2.7k) and accesskit are outside the 82,541. The skeptic noted these. They must be reimplemented or delegated, so the Bend share would fall.
- **Inconsistent description:** the verdict says native is "one Objective-C effect file". The same document counts 15,183 zui-equivalent native lines.
- **The right comparison:** `gpui_macos` is Rust (objc2/core-text bindings), plus 1,377 lines of MSL. GPUI's source is therefore about 98% one language, about 97% across 152,848 Rust lines against 4,530 shader lines. The Bend version is 82% Bend and 18% ObjC/C/MSL, so 18% of the macOS framework is in other languages, against 2% for GPUI. The verdict mentions that GPUI has shaders but never draws this comparison.
- **The headline:** the user asked for "fully Bend". The honest answer is "no, not fully", and the verdict opens "Yes". The qualification arrives after the headline.
**Suggestion**: Open with "No for fully; a GPUI-inspired reimplementation with an ObjC and MSL platform and render layer is viable, about 80% Bend by an unvalidated count". Recompute with macOS-irrelevant files removed, and list the lyon, taffy and resvg replacements.

### 8. [warning] Effort estimates have no basis in the evidence
**Location**: `explanation.md:107,243,280`, skeptic (premise-estimates) quoted text
**Finding**: "Demo 4-10 weeks, usable macOS subset 4-8 months" comes from a "10x discount" applied to line counts and from backplane-bend. The ledger itself says "Neither figure has a measured framework-scale data point".
**Evidence**:
- **Source scope:** the skeptic's 4-8 months included a Linux shim, text editing with IME, and "sustained frame-time tuning". The verdict relabels it "usable macOS subset".
- **backplane as calibration:** backplane-bend is 17.7k lines in 8 days by two authors with Claude co-authoring 132 of 229 commits. It is an app, X11 only, and no longer type-checks under 2.0.35. Scaled linearly, 67k lines would be about 30 days, which contradicts 4-8 months. The estimate cannot be derived from it either way.
- **Missing cost factors:** a 47k-line program took 107 s and 8.6 GB to build, with no incremental builds. The compiler is described as 99% AI-written, and the effect API is unstable (#1281). The 10x discount ignores these.
- **Ranking mismatch:** the P3 and P2 effort comparison ("probably not more work than P2") compares a 349-line prototype to the P2 pipeline. zui's native renderer plus shaders plus atlas is 4,638 lines. Blur, shadow, path and image pipelines and the real glyph atlas on the C side are unaccounted for.
**Suggestion**: Delete the numbers, or label them as a guess with the stated assumptions. Use the per-component prototype sizes as a floor only.

### 9. [warning] The P3 versus P2 speed ratios are inconsistent across documents and conditions
**Location**: `gapfill.md` ("12–35x"), `explanation.md:10` ("16-39x"), `explanation.md:112` ("16-20x" and "23-39x"), `wf2/all.json` measure table
**Finding**: Three ranges appear for the same comparison. From the cited rows I get 16.7 to 19.9x at 1x and 23.2 to 39x at 2x, which matches only the explanation. The 12x lower bound has no source.
**Evidence**:
- The P2 rows (`bin-cpu12` 8.34 ms and 16.48 ms, `bin-gpu` 7.84 ms and 24.22 ms) come from an earlier workflow, 5 runs x 30 frames, headless, measured at a different time and load. The P3 rows are 3 x 97 frames at load 3.3-3.7 for the runs whose log lines were captured.
- The ranges mix min and max cells across variants, so the ratios are ranges of ratios and not paired runs.
- The P3 side draws 8x16 4-bit glyphs with no atlas fetch, validated against P2's raster at the same size. The 4x-pixel 16x32 8-bit comparison was done for P2-hash and P2-tree only.
**Suggestion**: Re-run P2 and P3 alternately on the same scene and load, and report one ratio with its spread.

### 10. [warning] Whole-framework viability is extrapolated from layout, paint and a single IME test
**Location**: `explanation.md:3,208-209`, nothing in the prototypes
**Finding**: The verdict says Bend "can express the framework core". Several GPUI capabilities that the 67k-line count includes have no mapping in the verdict:
- **Async:** `cx.spawn` and foreground/background executors, with `scheduler` counted in the 67k.
- **Interaction:** subscriptions and observe/notify, drag and drop, tooltips, overlays, anchored popups, deferred draw, animation, window management and multi-window.
- **Content:** images, SVG and paths (lyon tessellation), backdrop blur, accessibility, and menus and dock.
**Evidence**: the only language-level risks examined are closures, traits and macros. Bend's single IO event loop with `need 0` inline effects and the `Window.frame` starvation behavior (`comp.ts:5858-5869`) are described, but how GPUI's async model maps onto them is not.
**Suggestion**: Add a feature-by-feature mapping with unknowns marked, and drop "can express the framework core" to "can express the layout and paint core".

### 11. [nit] The "build" timing label is not meaningful
**Location**: `p3stats.py`, `main_p3.bend:p3.loop`, `p3fx.c:207-210`
**Finding**: `build_us` is 9-12 µs for generating 256 quads and 2,000 sprites of 19 words each. That is 4.5 ns per sprite, which is implausibly fast for strict evaluation. Either the lists are built lazily and forced elsewhere, or the clock reads do not bracket the work. The unexplained 0.2 ms difference between effect wall time (0.373 ms) and the sum of GPU, walk and encode (about 0.157 ms) may be the commit and wait latency, or the forcing. `frame_us` as the total is still valid, but the per-stage columns are not.
**Suggestion**: Confirm via a Scene checksum that the lists are fully built before `t1`, or drop the stage columns.

### 12. [nit] Prototype details that limit what the numbers show
**Location**: `p3fx.c:158-160,206`, `ime-event-loop/`, `explanation.md:209`
**Finding**:
- **Clear color:** `0x191C21` is hard-coded and the Scene background is one flat color.
- **IME:** the IME shim and the P3 present effect were tested in separate loops. The present effect pumps AppKit events with `[NSApp sendEvent:]` while the IME snapshot has its own drain effect, and the two pumps were never run together. The IME result is 14 of 14 snapshots, synthetic keys and the German layout only.
- **Pixel check:** only one frame (frame 7) was compared with the Bend raster.
**Suggestion**: Run P3 present and the IME drain in one loop. Validate a few more frames, including scrolled ones.