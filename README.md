# Can zui be written in Bend?

Feasibility study, 4 October 2026. Subjects: [zeronsh/zui](https://github.com/zeronsh/zui) at `667d0aa` and [Bend 2](https://github.com/bendlang/bend) 2.0.35 at `565d7fd`.

**Verdict: viable, but not fully in Bend.**

Not fully, and not as a fork in the sense zui is one. A GPUI-style framework whose logic is Bend is viable. That logic covers the element tree, layout, text wrapping, hit testing, input dispatch, entity state, and the scene. Bend source cannot call native APIs, so the window, input, IME, clipboard, and CoreText calls must be an Objective-C layer of several thousand lines that Bend imports as effects. A Metal pipeline that draws the Bend-built scene should shade the pixels. This README calls that design path P3. In a real Retina window, P3 held 120 Hz on 98.6% of frames. When Bend code shaded the same frame itself, it ran at about 56 Hz.

| Number | What it measures | Source |
|---|---|---|
| 70–85% | Share of the macOS framework that would be Bend under P3, by attributing zui's modules. zui itself is about 98% Rust by the same count. | Estimate |
| 0.65 ms | P3 renderer per 3024×1964 frame with 256 cards and 2,000 glyphs, headless. | Measured and reproduced, 3 × 95 frames |
| 1.0–2.7 ms | Bend framework core per frame at steady state, 2,000 to 5,000 elements, minimal element model. | Measured, 2,000-frame runs |
| 17.9 ms | The same Retina frame when Bend code rasterizes it, full redraw, in a real window. | Measured, 3 × 115 frames |

An HTML version of this report is in [`research/artifact/bend-gpui.html`](research/artifact/bend-gpui.html).

## What "fully written in Bend" can honestly mean

zui is called a Rust framework, and by line count it nearly is. Its macOS build is about 98% Rust and 2% Metal shaders. Its Cocoa, Metal, and CoreText calls are Rust because Rust can call Objective-C directly.

Bend cannot do that. Native code enters a Bend program only through `.c` or `.js` files that a foreign effect imports, and only the event loop runs them. So every place where zui's Rust calls AppKit, Metal, or CoreText becomes Objective-C in a Bend version. That is about 14,000 zui-equivalent lines. Shaders are not the gap, because zui ships them too.

The estimate attributes zui's macOS framework (82,541 lines without tests, examples, and tooling) to the language each part would be written in. The Bend share lands between 70% and 85%, depending on where the boundary goes:

- It falls to about 69% if platform trait files, the executor, and half the text system count as native.
- It rises to about 85% if taffy counts as Bend. Taffy is the 22,150-line layout crate that a Bend version must also write.

The share describes responsibilities, not lines anyone has written.

| Build | Bend | Objective-C | Metal renderer and shaders | Rust |
|---|---|---|---|---|
| zui today (macOS) | none | none | ~2% | ~98% |
| Bend version, P3 | ~82% (range 70–85%) | ~13% | ~5% | none |

## One frame, from keypress to pixels

AppKit owns GPUI's loop and calls stored closures the moment an event arrives. A Bend program owns its own loop and pulls events once per frame. Every step below follows from that inversion.

1. **Objective-C.** AppKit delivers key, mouse, scroll, and IME events, and the native layer queues them. Typed text goes through `interpretKeyEvents` into an `NSTextInputClient` view. That view answers AppKit's synchronous questions from a snapshot that Bend pushed last frame.
2. **Objective-C.** A drain effect hands the queued events to Bend as one list.
3. **Bend.** Dispatch. Mouse events hit-test against last frame's hitbox list. Keys walk the focus path and keymap, with multi-stroke state held in Bend. Each match yields a `Msg` value, not a closure call.
4. **Bend.** `update(msg, store)` rewrites state. Entities are U32 ids into an `Array` slot table, threaded linearly through the frame.
5. **Bend.** `view(state)` builds the element tree as a closed sum type, such as `Div | Text | Img | List | UniformList`.
6. **Objective-C.** Text runs missing from the shape cache go to CoreText in one effect call. That costs 0.36 ms for 2,000 characters, or about 10 µs per changed line (measured).
7. **Bend.** Layout. A bottom-up measure pass, greedy word wrap over cached advances, then a top-down place pass for a flexbox subset.
8. **Bend.** Paint emits a flat scene (a quad list and a glyph list), the hitbox list, and the IME snapshot for step 1.
9. **Metal.** The present effect walks the scene lists and encodes instanced draws. The shaders compute rounded-rect SDFs and borders, and the GPU's blend hardware composites them. The prototype read every field in place from Bend's heap and blocked until the GPU finished. A production version should copy the scene into a packed buffer instead.
10. **Bend.** If nothing changed, block in a wait bounded by Bend's next timer instead of redrawing. That cut idle cost from 13% of a core and 57% GPU use to 1% and 3% (measured). End each frame with `IO.sleep(0)` so timers and channels run.

## Where Bend forces a different design

Each row is a GPUI mechanism that Bend 2 cannot copy, and the replacement that ran in this study.

| GPUI does | Why Bend cannot | Bend version, and its evidence |
|---|---|---|
| Stores listeners as `Rc<dyn Fn>` and calls them on every event (`div.rs:575`). | Closures are affine. A closure can be called at most once, and a record that holds one cannot be shared (`GUIDE.md:83`). | Nodes carry `Msg` values, and one top-level `update` interprets them. Ran with identical output on the JS and native lanes. |
| Erases element types with traits (`AnyElement`, `dyn Action`). | No traits, type classes, or macros. | A closed sum of element kinds plus a `Custom{kind, data}` arm. A 739-line sketch with 20 kinds, flex layout, and hit testing type-checks with no `@unsafe`. |
| Keeps entities in a ref-counted map and leases them out. | Values have one owner. No `Rc`, no `Drop`. | A U32 slot table in Base `Array`, released explicitly. GPUI's lease pattern maps over, because Bend already takes values out and reinserts them. |
| Calls CoreText from inside taffy's measure closure. | Effects cannot run inside pure layout. | A staged frame. Collect unshaped runs, shape them in one effect, then lay out. Measured at 0.36 ms per 2,000 characters. The cache lookup itself is unmeasured, and it could cost about 2 ms per frame at 1,250 text rows with String keys. |
| Answers `NSTextInputClient` queries by calling into the app synchronously. | No supported way for C to call Bend (no native library target, #813). | A per-frame snapshot that the native view answers from. Typed text, shifted keys, and dead keys arrived correctly on the German layout. A composition that stays open across frames was not tested, and neither was real Japanese or Chinese input. |
| Uses `i32`, `u64`, and `f64`. | Only `Nat`, `U32`, and `F32`. No signed U32 operations. | Two's-complement helpers. Nat ids hold up to 2^48−1 and fail-stop beyond that. |
| Generates about 114 Tailwind-style style methods with macros. | No macros beyond compile-time templates. | Generate them as Bend source with a script. |
| Runs inside `[NSApp run]` and draws during live resize. | Bend's event loop owns the process, and AppKit's nested resize and menu loops run inside a native call. | A custom frame loop instead of `App.run`. Frames stall during live resize and menu tracking unless C calls back into Bend through an unsupported runtime hack. Not prototyped. |

## Five paths compared

P1 uses only what Bend ships. P2 and P3 are rewrites that differ in which code shades the pixels. P4 and P5 are bindings in the style of [gpuix](https://github.com/remorses/gpuix), which wraps native GPUI.

Render cost at 3024×1964 with 256 cards and 2,000 glyphs. The figures are headless render, present, and drop, as the median and range of run medians, before the framework core. The budget at 120 Hz is 8.33 ms, and at 60 Hz it is 16.67 ms.

| Path | Variant | Median | Range | Budget |
|---|---|---|---|---|
| P3 | Metal draws the Bend scene | 0.65 ms | 0.59–0.69 | Fits 120 Hz |
| P2-CPU | Damage tracking, hover on one card | 2.36 ms | 2.02–3.99 | Fits 120 Hz |
| P2-CPU | Damage tracking, scrolling a text column | 7.96 ms | 6.71–8.25 | Fits 120 Hz |
| P2-CPU | Full redraw, Bend rasterizer on the CPU pool | 15.3 ms | 15.1–15.4 | Fits 60 Hz |
| P2-GPU | Full redraw, Bend rasterizer on `!` | 24.2 ms | 23.4–24.8 | Misses 60 Hz |

A P3 frame at 5,000 elements costs about 6.4 of the 8.33 ms on the critical path. That estimate combines measured parts that have not yet run together:

- the Bend core at 2.7 ms
- the in-window GPU time at its p90 of 3.5 ms
- the commit-and-wait latency at 0.2 ms

The prototype blocks Bend while the GPU works, so the GPU time counts in full. The p90 is used because the GPU clocks down between frames and overlaps with the window compositor. CoreText misses and shape-cache lookups are not in the estimate. Copying the scene into a packed buffer, and not waiting on the GPU, would take the 3.5 ms off Bend's path. The copy is unmeasured.

| Path | Bend writes | Native code | Measured | Blockers | Effort | Bend share |
|---|---|---|---|---|---|---|
| P1 Stock Base | Everything | Only Base's own `window.c` | 8.3 ms at 1x, vsync-capped | Fixed-size 1x window, no typed text or IME, 24-bit color with no alpha, no real fonts | Weeks to a demo. Parity impossible. | 100%, but a toy |
| P2-CPU | Core, rasterizer, glyph atlas | The same Objective-C layer as P3 | 17.9 ms full redraw in a 2x window. 8.3–8.5 ms with damage tracking for small changes | Needs damage tracking to hold 120 Hz at Retina. Full-screen changes run near 56 Hz. No alpha, blur, or MSAA in a 24-bit quadtree. | P3's work, plus a Bend rasterizer and damage tracking | Same native layer, Bend shaders |
| P2-GPU | Same, rasterizer on `!` | The same Objective-C layer | 24.2 ms at 2x headless. 52–106 ms incremental | Bend's GPU scheduler idles lanes on sparse, mostly flat UI frames. Idle gaps slow it 3–4×. | Same as P2-CPU | Same as P2-CPU |
| **P3 (recommended)** | Core, scene, IME state, shape cache | Objective-C layer plus a Metal renderer. The prototype has 61 lines of MSL. zui's renderer is 4,638 lines. | 0.42–0.65 ms headless. 120 Hz on 98.6% of 345 frames in a 2x window, worst frame 17.7 ms | Core and renderer not yet integrated. A resizable HiDPI window on stock Bend is unbuilt, because the test used PR #1108's patch. Live resize stalls frames. macOS only. | Months (guess) | 70–85% |
| P4 Bind zui | Model, update, and a view that emits mutations | All of zui (301 crates) plus a Rust C-ABI shim | Not measured | zui's macOS run loop blocks. Needs a patched `gpui_macos` like gpuix's fork. No C-to-Bend calls. | 1–3 months to a demo (guess) | 0% of the framework |
| P5 Bend in JS | Pure model, update, and view as `.mjs` | JS host, gpuix, forked GPUI | Not measured | The JS lane is single-core. The host language is JS. | Days | 0% |

### Why P3

- It is the only path that held 120 Hz at Retina with full redraws. It therefore needs no damage tracking, which is the hardest part of P2.
- The GPU's blend hardware gives alpha and antialiased edges. Blur, shadow, and path pipelines can be ported from zui's `metal_renderer.rs` and `shaders.metal`.
- It needs no `!` anywhere, which avoids every GPU-lane trap this study hit.
- Build it with a packed-copy scene buffer, the way GPUI does. That frees the shaders from Bend's internal heap layout and lets CPU and GPU work overlap.
- Keep a Bend rasterizer (P2-CPU) as the fallback where Metal is absent, such as Linux on X11.

### Why not Bend on the GPU

Bend can rasterize on the GPU. Its Slash Boss demo reproduced its documented 8 ms frame on this machine, at 7.2–8.3 ms over 3 × 1,192 frames. UI frames are the wrong shape for it. They are mostly flat, so the parallel work tree is sparse and GPU lanes sit idle. GPU render took 23.9 ms at 4 cards and 5.3 ms at 4,096 cards. Retina multiplies that cost. The framework core cannot run on `!` at all. Layout took 14.4 ms at 501 elements and then hit a stack overflow at 2,001.

## Is this "a gpuix for Bend"?

Only in purpose. gpuix gives JavaScript a GPUI front end, but it is a binding. It is a 26,125-line Rust napi crate over a GPUI fork (`remorses/zed`, branch `gpuix`), driven by a JS reconciler. Every non-Rust GPUI front end this study found works the same way, including gpui-moonbit and gpui-react. None of them reimplements GPUI.

zui has a different shape. It is one squashed commit that copies GPUI's source with Zed's crate paths kept, so upstream patches still apply with `git format-patch | git apply`. A Bend version cannot copy that, because no Rust patch applies to Bend source. It would be a GPUI-inspired reimplementation that follows upstream design changes by hand.

If you want apps written in Bend with GPUI's exact pixels, the binding paths (P4 and P5) get there faster, and none of the framework is Bend. If you want the framework itself in Bend, take P3.

## Risks

These risks could stop the project:

- **Upstream churn with no ABI promise.** This is the most likely failure. Bend's effect C API is internal by design, and open PR #1281 changes the signature of `io_eff`. Base constructor names are global, and Base's new `Scroll` constructor broke backplane-bend within a week. Pin a Bend commit, and keep the native layer behind a packed-copy boundary.
- **Text-heavy frames.** The core timed here uses a fixed advance table and one counter of state. Real shape-cache lookups over String keys, larger glyphs, and a real atlas are unmeasured. They consume the 1.9 ms left in the frame estimate.
- **Allocator slowdown (#1007).** It reproduces at HEAD, running 2.7× slower on 1 thread and 18× slower on 12. It grows with per-frame String churn. The core, which rebuilds 80,000 characters per frame, settled after 200 frames and kept memory flat over 2,000 frames. Runs longer than 17 seconds were not tested.
- **Text editing depth.** IME compositions that stay open across frames, CJK input, candidate-window placement, and reconversion are untested.
- **Build loop.** Bend has no incremental builds, and its JS lane cannot open a window. A 47k-line Bend program took 107 s and 8.6 GB of memory to build natively.
- **Reach.** P3 is macOS only. Bend has no Vulkan lane (#811) and does not run on Windows (#788).

These upstream changes would help:

- [PR #1108](https://github.com/bendlang/bend/pull/1108) adds resizable windows, a `Resize` event, and backing scale. It is open, labeled `later`, and no longer applies cleanly.
- [#813](https://github.com/bendlang/bend/issues/813), a native library target, would make C-to-Bend calls supported. That would fix live resize and synchronous IME queries.
- U64 (#1027) and F64 (#1120) would map GPUI's ids and hashes directly. `WONTFIX.txt` lists both as planned.
- #825, user handle types, would give unforgeable window and renderer handles.
- #1019 and #1022, typed text and IME in Base, would shrink the native layer.

## Effort is a guess

No framework-scale Bend project exists to calibrate against. The nearest is [backplane-bend](https://github.com/i2cjak/backplane-bend), a 17.7k-line Bend desktop UI written in 8 days by two people, with Claude co-authoring 132 of 229 commits. It is an app, not a framework, and it no longer type-checks under Bend 2.0.35.

These pieces are not built yet, even as prototypes: the core and renderer running together, a glyph atlas texture, clipping and content masks, images, shadows, paths, scrolling with clip, async tasks and subscriptions, drag and drop, menus, and accessibility.

## What the adversarial review changed

Three reviewers on Claude Opus, Fable, and Sonnet got the same prompt and tried to break the verdict. Then one agent reproduced the headline numbers alone on the machine. The P3 ranking survived. The corrections below are already applied to this report.

| Finding | Raised by | Change |
|---|---|---|
| "No missed frames" was false. | All three reviewers and the reproduction | The first run had 1 of 345 frames over 12.5 ms. The reproduction had 5 of 345, and the worst was 17.7 ms. The report now says 98.6%. |
| Safety came from a blocking wait, not the type system. | All three reviewers, confirmed by the reproduction | The prototype waits for the GPU before it returns the scene to Bend. Without that wait, Bend would reuse the memory while the GPU reads it. The recommendation now says to copy the scene into a packed buffer. |
| The core and the renderer never ran together. | All three reviewers | They use different scene layouts, and the core emits 40 times more glyphs than the renderer was timed with. The old "about 3 ms" total became a labeled estimate of 6.4 ms on the critical path. |
| Core cost climbed within every run. | Fable and Sonnet as critical, Opus as a warning | The reproduction ran 2,000 frames. Cost settles 12–26% above the first figures, then stays flat with flat memory. The report uses the settled numbers. |
| "82% Bend" was presented as a fact. | All three reviewers | It depends on boundary choices and swings between 69% and 85%. The report now gives the range, the method, and zui's own 98% for comparison. The verdict now answers "not fully". |
| The 2.55 ms in-window GPU time was called unexplained. | Opus diagnosed it, and the reproduction confirmed it | The GPU clocks down between vsync-paced frames and overlaps with the compositor. The fastest in-window frame matched headless. Because the prototype blocks, the p90 of 3.5 ms now counts in the frame estimate. |
| Effort numbers had no derivation. | All three reviewers | Month ranges were removed from P3. The report now lists what is unbuilt. |
| Live resize, idle cost, and open IME compositions were unexamined. | Opus on resize and IME, the completeness critic on idle cost | Live resize and the open-composition case are listed as untested risks. Idle cost was measured. Redrawing every vsync cost 13% of a core, and a timer-bounded wait cut that to 1%. |

## Evidence ledger

Measurements ran on an Apple M3 Pro with other applications open (load average 3–12, and up to 65% GPU use by other apps). Treat the GPU figures as upper bounds.

| Claim | Status | Evidence |
|---|---|---|
| Closures are affine. A closure field cannot be shared, and `f(f(x))` is rejected. | Confirmed | `GUIDE.md:83-85`, reruns on the JS and native lanes |
| GPUI listeners are shared, multi-call `Rc<dyn Fn>` closures. | Confirmed | zui `div.rs:575-582` |
| A GPUI-shaped core type-checks in pure Bend with Msg dispatch and no `@unsafe`. | Confirmed | 739-line sketch, identical JS and native output |
| Framework core costs about 1.0 ms per frame at 2,001 elements and 2.4–2.7 ms at 5,001. | Revised up | First reported as 0.80 and 2.15 ms on a ramp. 2,000-frame reruns plateau 12–26% higher, with flat memory. |
| The timed core is a minimal element model. | New | Fixed advance table, one counter of state, 3 element kinds, no shape-cache lookups |
| A CoreText shaping round trip costs 0.36 ms per 2,000 characters. | Measured | 3 × 100 iterations. The first call costs 9 ms. |
| Base output is only `Window.frame(Image)`, 24-bit, with alpha forced to 1. | Confirmed | `base.bend:74-76`, `window.c:360-384` |
| Base's macOS window is fixed size and 1x. | Confirmed | `window.c:214-230`. PR #1108 is still open. |
| Base events lack typed text, IME, resize, focus, and click count. | Revised | Modifiers arrive as separate key events. Shift+1 gives 33. |
| Native code enters only through `.c` and `.js` effects that the event loop runs. | Revised | Effects can also run work on `io_work` helper threads. |
| Linking an extra library needs `dlopen` or a compiler wrapper. | Refuted | `.linker_option`, or a module map plus `LIBRARY_PATH`, works with stock clang. |
| A custom effect must reuse the `Window` handle. | Revised | An affine id wrapper also works, but it can be forged. |
| The effect C API has no ABI promise. | Confirmed | `EFFECTS.md:136-139`. PR #1281 would change `io_eff`. |
| A `!` inside `App.run`'s view runs on the GPU. | Confirmed | 240 GPU calls per 120 frames, 0 CPU runs |
| The `!` flag belongs to the def, not the call site. | New | A plain call went to the GPU (16.6 ms), then crashed at 2,001 elements. |
| CPU pool vs `!` on UI frames. | Revised | Tie at 64–256 cards at 1x. The GPU wins at 1,024 cards. The CPU wins by 2–8× on sparse frames and at 2x. |
| Retina with a Bend rasterizer needs damage tracking to hold 120 Hz. | Reproduced | Full redraw is 17.9 ms in a window, with every frame late. Incremental is 8.3–8.5 ms. |
| P3 renders 256 cards and 2,000 glyphs in 0.42–0.65 ms headless. | Reproduced | 3 × 95 frames by two agents. One run was 2× slower because of external GPU load. |
| P3 holds 120 Hz in a real 2x window. | Revised | 98.6% of 345 frames under 12.5 ms, worst frame 17.7 ms. The runtime was patched with PR #1108. |
| P3's GPU read of the Bend heap is safe. | Revised | Only because the effect calls `waitUntilCompleted` before it returns (`p3fx.c:284-294`). |
| In-window GPU time is 2.55 ms against 0.34 ms headless. | Explained | The GPU clocks down between paced frames and overlaps the compositor. The p90 is 3.5 ms, and the minimum equals headless. |
| Idle redraw cost, and the bounded wait. | Measured | Redrawing every vsync costs 13% CPU and 57% GPU. A timer-bounded wait costs 1% CPU and 3% GPU, and timers stay on schedule. |
| IME works through a per-frame snapshot. | Partly | Typed and dead-key text arrived correctly on the German layout. No composition that stays open across frames was tested. |
| C can call Bend synchronously through a `corpus_eval` re-entry. | Works, unsupported | 20,000 calls and 301 GPU calls inside AppKit callbacks, 0 mismatches |
| Allocator slowdown #1007 affects a UI workload. | Scale-dependent | The issue's repro runs 2.7–18× slower. UI workloads stayed flat over 2,000–20,000 frames. |
| Numbers are only Nat, U32, and F32. | Revised | Nat holds 48-bit values. U32 has no signed operations. |
| zui's macOS run loop blocks and has no `pump_events`. | Revised | Headless mode blocks too. |
| Every non-Rust GPUI front end binds GPUI rather than rewriting it. | Confirmed | gpuix, gpui-moonbit, gpui-react |
| Share of the macOS framework that is Bend. | Estimate | 70–85%, depending on boundary choices. zui is about 98% Rust by the same count. |
| Effort. | Guess | No framework-scale Bend project exists to calibrate against. |

## How the study ran

Four explorers read zui, Bend 2, and the prior art, ran Bend's window demos, and benchmarked the render path. Five skeptics then tried to refute each claim, and one benchmark agent ran alone. A completeness critic named the gaps. A gap-filler built the prototypes that time the core, test Retina damage tracking, test P3, and test the allocator. Reviewers on three models attacked the result, and a final agent reproduced the headline numbers alone.

A last probe started after the report was published. It tested which UI invariants Bend can prove, gathered evidence of demand for a Bend UI library, and tried Bend logic on top of gpuix. That probe was stopped before it finished, so its partial output is not included.

## Repository layout

`research/` mirrors the scratchpad where the study ran. Paths in the reports that begin with `research/` or `S/` resolve inside it.

| Path | Contents |
|---|---|
| `research/wf1/` | Explorer reports (`gpui-anatomy.md`, `bend-capabilities.md`, `prior-art.md`, `gpu-render-path.md`) and the extracted claims (`claims.json`) |
| `research/wf2/` | Skeptic verdicts and benchmark results (`all.json`), the synthesized explanation (`explanation.md`), and the gap-fill report (`gapfill.md`) |
| `research/wf3/` | The three adversarial reviews and the reproduction results (`repro.json`) |
| `research/v/` | Prototypes and benchmark harnesses with their logs. Key files: `bend-language/sketch/ui.bend` (core sketch), `gapfill/core/` (core timing), `gapfill/p3/p3fx.c` (P3 renderer), `gapfill/dirty/` (Retina damage tracking), `gapfill/ct/shape.c` (CoreText), `ime-event-loop/` (IME snapshot), `measure/` (render-path benchmark) |
| `research/a/exp/`, `research/b/exp/`, `research/c/exp/`, `research/d/exp/` | Explorer experiments |
| `research/artifact/bend-gpui.html` | The HTML version of this report |

The prototypes build against a Bend checkout at `565d7fd`. That checkout is not included. To run them, clone [bendlang/bend](https://github.com/bendlang/bend) to `research/b/bend` or `research/d/bend`, where the scripts expect it. The repository leaves out compiled binaries, generated C files, GPU archives, texture dumps, and copies of third-party repositories.

## Sources

- [zeronsh/zui](https://github.com/zeronsh/zui)
- [bendlang/bend](https://github.com/bendlang/bend), formerly HigherOrderCO/Bend
- [remorses/gpuix](https://github.com/remorses/gpuix)
- [i2cjak/backplane-bend](https://github.com/i2cjak/backplane-bend)
- [aricarmo/godot-bend](https://github.com/aricarmo/godot-bend)
- [subtleGradient/bend-ui](https://github.com/subtleGradient/bend-ui)
