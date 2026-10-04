## Findings

All paths below are under `S = research`.

### 1. [warning] The "holds 120 Hz in a real Retina window" result has no headroom in it, and the "about 3 ms" end-to-end estimate leaves out costs that the core benchmark's own scenario incurs
**Location**: S/wf2/explanation.md:8, :107; S/wf2/gapfill.md:103-106; S/v/gapfill/win/p3w_r{1,2,3}.{out,err}; S/v/gapfill/core/core_main.bend:56-58; S/v/gapfill/core/core_lib.bend:534-546
**Finding**: The window run shows only that the present path follows vsync when Bend does about 40 µs of work per frame. The "about 3 ms with a 5k-element core" figure is the sum of two numbers that were never run together, and it is missing several terms.
**Evidence**:
- In p3w, the P3.present effect wall time has medians of 8.03, 8.09 and 8.13 ms out of an 8.25 ms frame. Scene build is 27-43 µs. The effect blocks the Bend thread for almost the whole frame, so these runs tell you nothing about spare time.
- The end-to-end pipeline never ran. P3 reads ui_common's `Qs`/`Gs` layout (19-word glyph nodes with the bitmap rows inline). The core emits a different `Scene`/`SpCon` layout (core_lib.bend:421-430).
- Terms missing from "about 3 ms":
  - **Scene drop.** The core benchmark drops the Scene after `t4`, outside `core_us` (core_main.bend:56-58). At 79,985 sprites it should cost about 1 ms, using P3's measured 31 µs per 2,257 nodes.
  - **Glyph volume.** P3 was only timed with 2,000 glyphs. The 5k-element core emits about 80,000, so the walk alone grows from about 8 µs to about 0.3 ms.
  - **CoreText.** `rowtext` changes every row's string every frame (`c` increments through the hit dispatch). At the measured 10 µs per changed line, really shaping that text costs about 5 ms at 2,001 elements and about 12.5 ms at 5,001. Either the "nothing cached" scenario is not the one being estimated, or the budget breaks.
- The verdict says 2,000-5,000 elements "does not by itself force retained layout or view caching". That only holds with a high hit rate in a text-shape cache, which the benchmark's own scenario rules out.
**Suggestion**: Run core_lib → P3.present in the 2x window: core Scene, real CoreText through a shape cache with a stated hit rate, drop inside the timed frame. Report how long the Bend thread is busy per frame, not frame intervals locked to vsync.

### 2. [warning] The verdict credits affine typing with keeping the GPU read safe; the real reason is a blocking wait, and the copy-based alternative was never measured
**Location**: S/wf2/explanation.md:34, :94, :207; S/v/gapfill/p3/p3fx.c:284-285, :294; S/v/gapfill/p3/main_p3.bend:38-40; S/v/gapfill/p3/main_p3win.bend:33-36; S/a/zui/crates/gpui_macos/src/metal_renderer.rs:598-624
**Finding**:
- **The prototype is safe, for a different reason than stated.** p3fx.c calls `[cb commit]; [cb waitUntilCompleted];` before `io_tup(e, qs, gs)`. Its timings are therefore of a safe design. But the explanation's "affine typing therefore keeps the Scene alive while the GPU reads it" is wrong. Both drivers drop the lists right after the effect returns (`p3.drop(d)`, `p3w.drop(d)`). Affine typing protects nothing after return. The only protection is the blocking wait.
- **The wait has a cost.** Anyone who removes it to overlap CPU and GPU work, as GPUI does, gets a GPU use-after-free. GPUI copies primitives into a pooled instance buffer, commits without waiting, and releases the buffer in a completion handler.
- **Reading in place couples the shaders to runtime internals:**
  - raw word offsets (p3fx.c:63, :77-85);
  - the refcount redirect, which `p3_loc` reads as a plain word (p3fx.c:188-190), although the runtime says a host must never read that cell as one plain word (comp.ts:3878);
  - flat, scalar-only nodes. GPUI's `Quad` nests `Bounds`, `ContentMask`, `Background`, `Corners` and `Edges` (scene.rs:613-623). Matching it either flattens everything into one constructor or makes the shaders chase heap pointers.
- **The alternative was never measured.** A packed copy would fix all of the above, and would let zui's 1,377-line shaders.metal be reused nearly verbatim if the C walker writes GPUI's `#[repr(C)]` layouts. The verdict dismisses it as "estimated at tens of µs, not measured".
**Suggestion**: Make the packed copy into a pooled buffer the P3 baseline and measure it at 2k and 80k primitives. Correct line 94 to name the synchronous wait as the safety mechanism.

### 3. [warning] The 2.55 ms in-window GPU time is mostly waiting for a drawable, and it is reported as an unexplained blocker
**Location**: S/wf2/explanation.md:107; S/wf2/gapfill.md:104; S/v/gapfill/win/p3w_r*.err; S/v/gapfill/p3/p3fx.c:267-285
**Finding**: The in-window `gpu_us` mixes shading with waiting for the drawable. The `encode_us` interval (event pump plus a blocking `nextDrawable`) and `gpu_us` trade off almost one for one.
**Evidence**:
- Across the 115 kept frames per run, corr(encode_us, gpu_us) is -0.69, -0.71 and -0.89, and encode+gpu stays at 7.04-7.28 ms.
- The minimum in-window `gpu_us` is 444-611 µs, close to the headless 342 µs.
- Base's layer is capped at 2 drawables (window.c:232). That fits back-pressure from vsync plus the GPU waiting until the compositor releases the drawable.
- The shading cost is probably fine. The real issue is that GPUStart-to-GPUEnd time cannot measure shading in this setup.
**Suggestion**: Measure GPU time on an offscreen pass blitted to the drawable, or read GPU counters. Drop the "unexplained" blocker, or replace it with this explanation.

### 4. [warning] Core frame cost climbs 1.6-2.2x within every 110-frame run; the reported medians understate steady state, and the allocator verdict was tested on a 15-40x lighter workload
**Location**: S/v/gapfill/core/mx/one-cpu12-{125,500,1250}_r*.out, staged-cpu12-1250_r*.out; S/wf2/gapfill.md:27-29, :135; S/wf2/explanation.md:90, :208
**Finding**: The amount of work is constant (`ns` 79,980 → 79,985), yet time per frame rises steadily in every run. This was not flagged.
**Evidence**:
- Per-10-frame medians at 5,001 elements: r1 rises 1,299 → 2,492 µs, r2 1,294 → 2,268, r3 1,215 → 2,254.
- At 2,001 elements: 507 → 919 µs. At 501: 110 → 180 µs.
- Every staged phase rises: view 272 → 588 µs, layout 630 → 1,016, paint 331 → 659.
- P3 frames in the same session are flat, so this is not machine-wide drift.
- The headline 2.15 ms is a median that includes the ramp; the last blocks run 2.25-2.5 ms. 110 frames cannot tell a plateau (likely heap locality) from slow growth.
- The allocator verdict ("no slowdown for ~2,000 chars per frame") comes from drift4. The core itself rebuilds about 31k-80k characters plus about 80k sprite nodes per frame, close to the 160K-character onset that Gap 4 measured for #1007.
**Suggestion**: The rerun agent should run core_lib at 2,001 and 5,001 elements for 2,000+ frames, report per-100-frame medians and RSS, and use the steady-state value in the verdict.

### 5. [warning] The core that was timed is a toy next to GPUI, and "that core measured 0.17-2.15 ms" implies it covered the entity store
**Location**: S/wf2/explanation.md:3; S/v/gapfill/core/core_lib.bend:43-45, :144-150, :504-512, :538-546
**Finding**: The verdict lists the element tree, flex layout, text wrapping, hit testing, Msg dispatch and the entity store, then says "That core measured 0.17 to 2.15 ms". The timed program is much smaller than that list.
**Evidence**:
- State is one `U32` counter (`update(m, c)`). There is no Array slot-table entity store; that exists only in the untimed ui.bend sketch.
- `Style` has 9 fields. GPUI's `Style` has dozens, plus refinement.
- The tree uses only 3 element kinds (Div/Text/Spacer+Button rows).
- There is no clipping or content mask, no element-state lookups, no dispatch tree or focus path, and the hit test is a linear list.
- Text advances come from a hard-coded table (`adv`), not CoreText.
- No GPUI or Rust baseline was run on the same tree, so the cost per element cannot be judged.
**Suggestion**: Describe the number as a lower bound for a minimal element model. Time the sketch's entity store and a GPUI-sized boxed Style.

### 6. [warning] "82% Bend" uses the wrong yardstick for "fully written in Bend" and drops the caveat about external crates
**Location**: S/wf2/explanation.md:10, :105-107, :279; premise-estimates finding in S/wf2/all.json (around line 421)
**Finding**: By zui's own standard, GPUI-macOS counts as "written in Rust" even though it ships 1,377 lines of MSL (4,530 lines of shaders across all platforms). On that standard it is about 98% Rust: 81,164 of 82,541 lines.
**Evidence**:
- **The shortfall is FFI, not shading.** The real gap between zui and a Bend version is the roughly 13.8k lines of platform and renderer-host code that zui writes in Rust and Bend must write in Objective-C, because native code enters only through `.c`/`.js` effects.
- **P2 is not "more fully Bend".** The verdict presents P2's 87% as "having Bend shade the pixels too", which treats shader code as a purity cost that zui itself does not pay. P2 has the same 10.5k-line Objective-C shortfall.
- **The 82% has false precision:**
  - The numerator counts code that would vanish rather than become Bend: scheduler 2,760, executor.rs 498, arena, profiler 822, and the platform.rs traits at 2,886.
  - The explanation drops the premise-estimates caveat that the external crates (taffy 22k, etagere, resvg, image decoding) are outside the count. Taffy would add to the Bend side; the atlas allocator and image/SVG decoding would likely add to the native side.
**Suggestion**: Say instead: "Bend wherever zui is platform-independent Rust; Objective-C wherever zui's Rust calls AppKit, Metal or CoreText (about 14k zui-lines); MSL as in zui". Give the percentage with its caveats, or drop it.

### 7. [warning] The effort estimates have no derivation that can be traced, and the calibration facts conflict
**Location**: S/wf2/explanation.md:20, :107, :243, :280; skeptic effort text in S/wf2/all.json ("10x discount ... one agent-driven engineer")
**Finding**: "Demo 4-10 weeks" comes from an arbitrary 10x discount on backplane-bend's rate, for "one agent-driven engineer". The verdict drops that staffing qualifier. "4-8 months" came from an earlier draft with no derivation at all.
**Evidence**:
- The two sources disagree about the calibration project. The explanation says 17.7k UI lines, 2 authors, 229 commits. The skeptic says 91,425 lines, one author, 330 commits.
- The stated reason to trust the shorter figure ("the riskiest pieces now exist as working prototypes") overstates readiness. The prototypes were never integrated:
  - P3 reads a different Scene layout than the core emits;
  - the IME shim ran on Base's `Window.frame` loop, not P3's;
  - CoreText is not wired into layout;
  - the P3 window drops all events;
  - the glyph-atlas texture path, resize, HiDPI and the drain effect are unbuilt.
- The ledger itself admits "Neither figure has a measured framework-scale data point."
**Suggestion**: State the staffing model and the scope of each figure, or present them as unanchored guesses.

### 8. [warning] The IME evidence never covered a composition that stays open across a Bend frame
**Location**: S/wf2/explanation.md:209, :265; S/v/ime-event-loop/run2.txt:2-177
**Finding**: The verdict says "dead keys and marked text ... matched 14 of 14 snapshots". All 14 snapshots have `mark={NotFound}`.
**Evidence**:
- Every composition (´, `, k → か → かな → 仮名) was opened and committed within one frame, before Bend pushed a snapshot.
- Three of the snapshots are trivial empty states, and several are duplicates.
- The hard case for a snapshot design was never exercised: Bend pushes `{text, caret, marked}` while the shim holds marked text that Bend has not drained yet.
- `firstRect` returns the same `(895,775 1x18)` for every range.
**Suggestion**: Add a test where marked text spans at least 3 Bend frames, including a frame where Bend pushes a stale snapshot mid-composition.

### 9. [warning] Event-loop ownership: P3 blocks AppKit on the main thread and cannot draw during live resize or modal tracking loops; this is not raised
**Location**: S/v/gapfill/p3/p3fx.c:267-285; S/b/bend/bend2/effs/window.c:449-484; S/wf2/explanation.md:61-66, :200-232
**Finding**: p3_go drains events once, then blocks the main thread in `nextDrawable` and `waitUntilCompleted` without servicing the run loop, for about 8 ms per frame.
**Evidence**:
- Base's own `window_show` takes `nextDrawable` on a helper thread and pumps the run loop while it waits (`window_wait`). P3 regressed this.
- AppKit runs live resize and menu tracking as nested loops inside `[NSApp sendEvent:]`, which sits inside the P3 effect. During them Bend cannot produce frames, and its timers starve.
- GPUI draws during those loops because AppKit calls into it. Bend has no supported host-to-Bend calls (#813), so the only option is the `corpus_eval` hack.
- The P3 window was fixed size, so none of this was tested.
- Idle blocking (critic gap 5) is still open. An effect that blocks on NSEvent cannot see Bend's timer deadlines.
**Suggestion**: Add live resize and idle wait to the risks, and prototype both before committing to P3's loop design.

### 10. [nit] The headline speed multiplier is stated three ways, and the top of the range compares against the worst P2 variant
**Location**: S/wf2/explanation.md:10, :112; S/wf2/gapfill.md:10, :106; measure results_table in S/wf2/all.json
**Finding**: The multiplier appears as "16-39x" (explanation, verdict), "16-20x at 1x / 23-39x at 2x vs the best P2 variant" (explanation, recommendation) and "12-35x" (gapfill and the task intent).
**Evidence**:
- At 2x the best P2 variant is bin-cpu12 at 16.48 ms, which gives 23-27x against P3's 0.62-0.71 ms. The 39x figure is bin-gpu (24.22 / 0.622), the worst variant.
- The 12x figure only comes out by dividing 1x P2 times by 2x P3 times.
- The P2 and P3 runs were in different sessions and not interleaved.
- P2-CPU is a compute-bound 12-thread job measured at load average 4.5-11, so external load hurts it more than single-threaded P3. The ratio leans toward P3, though the ranking is not in doubt.
- Gap 2's P2 2x rows use 16x32 8-bit glyphs; P3's 2x runs use 8x16 4-bit glyphs.

### 11. [nit] The configuration measured is not the one recommended
**Location**: S/v/gapfill/p3/main_p3win.bend:66; S/v/gapfill/p3/p3win.c (`#define BANGS 1`); S/v/gapfill/win/p3w_r*.err (`shared 1`); S/v/gapfill/run_win.sh:2; S/v/bend-window-runtime/bend-pr (uncommitted window.c/base.bend); S/v/gapfill/build.sh:8; S/wf2/explanation.md:97-98, :114
**Finding**: The verdict prescribes "BANGS 0, no .gpu archive, no `!`". The measured binaries differ:
- **Bangs in both binaries.** Both P3 binaries call `Image.drop!(Pix{0})` (p3win BANGS 1, p3 BANGS 3), and they compiled a `.gpu` program.
- **Shared GPU runtime in the window run.** The window run used the bang runtime's `gpu_que`/`gpu_buf`. The own-device, no-copy path was timed only headless with `--gpu off`.
- **Patched runtime.** The 2x window ran on a 565d7fd checkout with PR #1108's window.c and base.bend patched in, uncommitted. build.sh's default points at the stock checkout, and the explanation's P3 window claim does not mention the patch.

### 12. [nit] "No missed frames" is literally false
**Location**: S/wf2/explanation.md:8; S/v/gapfill/win/p3w_r1.out (frame 29: 13,992 µs)
**Finding**: One counted frame went over 12.5 ms (1 of 345, 0.3%). `winstats.py` averages per-run fractions and prints with `:.0f`, so it shows "0%".

### 13. [nit] p3_corpus dropped Base's buffer-limit guard
**Location**: S/v/gapfill/p3/p3fx.c:173-183 vs S/b/bend/bend2/effs/window.c:425-447
**Finding**: Base fails with `err_fail` when the heap is past `maxBufferLength` (window.c:434). P3 silently caps the wrapped length, so a large heap would produce unchecked out-of-range GPU reads. The shared path has the same problem with `gpu_buf`, which `gpu_span` caps at 2 GB or less. This does not affect the numbers.

### 14. [nit] Only one validation dump exists on disk
**Location**: S/v/gapfill/p3/{blit_7.raw,p3_7.raw}; S/wf2/gapfill.md:92
**Finding**: I recomputed the 1920x1200 pair with a pure-Python comparison: 95.19% of pixels exact, 100% within 1 step, max difference 1. That matches the report. The claim that it also holds "at both resolutions, on both executors, mode 2" cannot be checked, because no dumps for those cases were kept.