### Components Found

**1. subtleGradient/bend-ui** (clone: `research/c/bend-ui`)
- The repo is docs only. It has 2 commits: `0660c15b` "docs: research Bend UI direction" and `33177712` "docs: design Bend native reconciler", both dated 2026-09-21 UTC. It has no issues, no PRs and no code. The research is dated 2026-09-20, which is the Bend ~2.0.20 era.
- `AGENTS.md` is Bend's standard 4-line agent snippet (`bend guide`, `LAWS.bend`, `bend PROOF.bend`, parallelize).
- **`gpui-bend-research.md`**
  - Conclusion: "should not be called a GPUI Kit port". It says to build a new declarative library, `bend-ui`, that borrows GPUI's lessons rather than its API.
  - Its baseline is GPUI Kit (longbridge/gpui-kit, ★16,092), not zui.
  - Proposed stack:
    1. A pure typed `Ui<Msg>` tree plus style/token library.
    2. An Elm-like `init`/`update`/`view`.
    3. A keyed reconciliation and host-event protocol.
    4. A browser renderer first, then a native renderer "which may use GPUI or GPUI Kit behind a narrow Rust/C boundary".
  - Nodes carry data messages, not closures, because closures are affine.
  - Missing systems it lists: flex/grid layout, text shaping, text editing/IME, selection, scroll physics, pointer capture, accessibility, overlays, retained focus, icons/assets, native controls. It says these, "not merely JSX", are the real product work.
  - Proofs only cover pure laws: update invariants, normalization idempotence, no duplicate keys, a disabled button emits nothing. Paint, focus, IME and accessibility stay outside proof.
- **`bend-native-reconciler.md`** ("Decision: the stronger near-term direction")
  - A pure Bend shadow tree plus keyed reconciler that emits a patch plan (`Mount`, `SetProp`, `InsertChild`, `MoveChild`, `Remove`, `Replace`, `Dispose`) to *native platform controls* (DOM, AppKit, GTK, Qt, TUI).
  - It explicitly says not to reimplement text editing, focus, menus, accessibility, scrolling or buttons in Bend. Custom graphics would be an explicit `Canvas` node.
  - `RawEvent` (`Pressed(id)`, `TextEdited`, ...) crosses the FFI. `Msg` never does.
  - Adapters are chosen by static module import; there is no runtime dependency injection.
  - Bridge encoding: prototype by walking Bend terms in C; for a product, use a versioned compact patch schema with codegen.
  - Constraints it names: only `.c`/`.js` foreign files; no traits or conditional imports; JS lane is sequential with no graphics; strings are linked lists.
  - Note: this direction (native widgets) is the opposite of GPUI's custom-drawn model.
- **`bend-jsx.md`**: build the library-owned `Ui` builder API first, then an optional JSX or `ui:` indentation syntax that lowers to ordinary constructors in `bend2/bend.ts` `parse_term_base`. Phase 4 is a "Native GPUI/GPUI Kit host adapter".

**Checking bend-ui against Bend 2.0.35** (clone `.../c/bend`, HEAD `565d7fde` 2026-10-04, `bend2/main.ts:33 VERSION = "2.0.35"`):

| Claim | Status |
|---|---|
| `Image` is only `Pix{color}` / `Qua{tl,tr,bl,br}` | Holds (`bend2/base.bend:74-76`). |
| `Event` is only Key/Mouse/Move/Close | **Outdated.** Now also `Look{dx,dy}` and `Scroll{x,y,dx,dy}` (`base.bend:78-84`), added in 2.0.32 via PR #1073 and PR #1114. |
| `App<S>` shape | Holds (`base.bend:120-121`). |
| `Window` is an affine opaque handle; `Window.frame` returns it beside the image and events | Holds (`base.bend:105-106`, `373-399`). |
| "checked macOS `window_frame.c` bridges runtime terms to AppKit/Metal" | Holds, but the file is now `bend2/effs/window.c`. All window effects were merged into it in 2.0.32. Its Metal kernel (`window_msl`, lines 359-384) reads the Bend heap directly, using `TAG_CTR`, `RFC_BIT` and `LOC_MASK`. |
| Foreign files are only `.c` and `.js` | Holds (`comp.ts:2722-2735` `effect_srcs(fl, ".c"/".js")`). |
| JS lane sequential, no graphics | Holds (`bend2/effs/window_open.js` always returns `Fail` "no display"; README limitations). |
| `bend page.html -o dist` exists | Holds (guide line 553). |
| Strings are linked lists; no traits/macros | Holds (README limitations). |
| New since then | 2.0.32 added `-o x.mjs`, an ES module of the non-IO defs (#1029). This strengthens bend-ui's browser-first plan. |
| Not covered by bend-ui | User handle types are WONTFIX (#825). Native library target is deferred (#813). The page-target PR was rejected (#866). |

Checking bend-ui's GPUI claims against zui (clone `.../c/zui`, HEAD `667d0aaf` 2026-09-30):
- These hold: elements are rebuilt per frame, durable state lives in `Entity<T>`, layout is web-style.
- Its claim that GPUI Kit "does not expose a drop-in C ABI" holds for zui too. A code search finds `extern "C"` only for outbound platform calls and no `no_mangle`.

**2. subtleGradient/bend-over** (clone `.../c/bend-over`, pinned to Bend 2.0.29 in `toolchain.json`)
- It contains nothing UI or graphics related. Packages: sqlite, js-eval, browser-io; math-dsl is a wishes doc only.
- Relevant patterns:
  - `demos/js-effects/web.bend` declares **JS-only foreign effects**: `import "./effects.js"` with no `.c` twin.
  - `packages/browser-io/runner.js` is a 34-line browser interpreter that `await`s Promise-returning effects. It rejects parked effects, spawn and channels.
  - `packages/sqlite/sqlite.bend` wraps Base's `File` handle (`Connection{handle: File}`) because user handle types are not allowed.
  - `packages/sqlite/effs/sqlite.c` reaches the native library through `dlopen` (`bs_load`, `BEND_SQLITE_LIBRARY`), not through link flags.
  - The README says BendHub's source packager does not ship companion (non-.bend/.c/.js) assets.

**3. Bend's own graphics surface**
- `bend2/effs/window.c` (847 lines):
  - macOS: `NSWindow` + `CAMetalLayer`. `styleMask` is Titled|Closable|Miniaturizable, so the window is **not resizable**. `drawableSize = (w,h)`, with no `backingScaleFactor`, so there is no HiDPI. The title is created Latin-1 at open.
  - Keys come from `charactersIgnoringModifiers lowercaseString`. There is no text or IME path.
  - `window_corpus` maps the whole Bend heap as a Metal buffer (`newBufferWithBytesNoCopy`). A compute kernel walks the `Image` quadtree per pixel.
  - Linux: X11 with `XPutImage`, `window_sq` fill on CPU or a CUDA kernel, paced at 60 Hz.
- `effs/audio.c` exists.
- `demos/app_slash_boss_3d/bend3d.bend` (58 KB) is a full software rasterizer in Bend with a stroke font (`Font.glyph`, `Text.put`, lines 956-1137).
- `guide/SHADERS.md` reports 1920x1200 at 120 FPS (8.0 ms/frame) on a 10-core M4 mini: host builds a cell quadtree, then one `!` per frame forks to 4^7 tiles.
- `guide/EFFECTS.md` documents the C/JS effect ABI and states "There is no ABI promise. Rebuild your effects with every update."

**4. WONTFIX.txt items relevant to UI**
- DESIGN: "A handle type is a law of Base (#825)". A custom effect must reuse `File`, `Socket`, `Window`, etc.
- DESIGN: "`!` goes to the GPU only at the root of an IO step (#1065)".
- DESIGN: "Allocation failure fail-stops the runtime (#792)".
- DESIGN: "The C compiler is clang only (#773)".
- DESIGN: "No common-subexpression elimination (#812)".
- CAPACITY: "No Vulkan or other extra GPU lanes (#811). Metal and CUDA only."
- CAPACITY: "Windows is not supported".
- CAPACITY: "Server helpers stay out of Base (#1106, #1117)": "Base holds the effects no library can build... ship it as a hub package."
- CAPACITY: "No cancellation of blocking effects (#1034)".
- RUNTIME: unbalanced `Array` fail-stops (#808); Nat > 2^48-1 or array past block class 31 fail-stops (#779).
- SOON: U64 (#1027) and F64 (#1120). Maintainers write their own and "do not merge PRs" for them.
- SOON: "A native library target for pure defs (#813)... planned, not scheduled."
- SOON: JS-lane CPS for deep recursion (#798, #802).
- No entry rules out mutation: `Array` gives in-place writes, and `Array.fork`/`Array.atomic` exist under `@unsafe` (#885). No entry rules out callbacks into Bend, but no mechanism for them exists either.

**5. Bend issues and PRs** (raw JSON in `.../c/issues/`, `.../c/prs/`; GitHub has no Discussions for bendlang/bend)
- Merged or fixed in 2.0.32 (all by community PRs):
  - #1020 Scroll events (https://github.com/bendlang/bend/issues/1020, PR #1114 by oxura).
  - #921 `Window.grab`/`Look` (PR #1073).
  - #842 run-loop lag. Maintainers moved `nextDrawable` to a helper thread.
  - PR #1115 Linux square fill (credited and ported).
  - #874: foreign defs are now reported as trust dependencies.
  - #1029 `-o .mjs`.
- Open with no maintainer reply:
  - #1021 resize/size events (https://github.com/bendlang/bend/issues/1021), with PR #1108 `Window.open_resizable`/`Resize{w,h}`/backing scale open since 2026-09-27 (https://github.com/bendlang/bend/pull/1108).
  - #1019 no uppercase / typed text.
  - #1022 no IME (https://github.com/bendlang/bend/issues/1022).
  - #923 fullscreen.
  - #1237 / PR #1241 `Window.export_ref`.
  - #1148 a JS effect cannot await Promises, timers or signals (https://github.com/bendlang/bend/issues/1148).
  - #1144 `.d.mts` declarations.
  - #1007: long-lived native processes slow 3-17x on repeated identical allocation work (free chains lose address order).
  - #1307: similar slowdown on 2.0.35.
- Refusals and stated plans:
  - #920 WGSL/WebGPU lane, closed by VictorTaelin 2026-09-27: "an extra GPU lane... WONTFIX.txt, CAPACITY, rules those out" (https://github.com/bendlang/bend/issues/920).
  - PR #866 wasm page target with Window on canvas, closed by pjcavalcanti 2026-09-24: "Bend is a language, not a web framework... The same Bend program should be able to run with a native window or inside a larger web application whose page the user controls". He sketched a `--library -o game.wasm.js` with a user-supplied canvas as an illustration only (https://github.com/bendlang/bend/pull/866).
  - #813 native library target: "a new lane... out of scope for now", then moved to SOON (https://github.com/bendlang/bend/issues/813).
  - #825: user handle type made a WONTFIX DESIGN entry ("opening it touches consistency").
  - #1106: "Base keeps to the effects no library can build... we would be glad to see it on the hub."
  - #350 (Bend 1, 2024): Victor promised "call arbitrary C functions via FFI". Bend 1 added dlopen. Closed as Bend 1.
  - README: "Bend works best on the back-end".

**6. "gpuix"**
- remorses/gpuix (★2,536, created 2026-01-29) is "Node.js & Bun bindings for Zed's GPUI. Build memory efficient native apps with React or Solid.js". An ecosystem has grown around it: khromov/gpuix-svelte ★210, jhomra21/gpuix-solid, drewnekota/gpuix-ui, galaxiajs/gpuix (browser fork), gpuix-android, and others. AzureZee/gpuix ★2 is an unrelated GPUI fork.
- So "a gpuix for Bend" most likely means **Bend bindings and a Bend-side view layer over GPUI**, not a rewrite.
- gpuix's own structure (clone `.../c/gpuix`, HEAD `4ecca30f`):
  - Rust `packages/native` is a napi-rs cdylib. `find packages/native/src -name '*.rs' | xargs wc -l` = 26,125 lines.
  - It depends on a GPUI fork submodule (`.gitmodules`: remorses/zed, branch `gpuix`).
  - The JS reconciler sends an atomic `applyBatch` mutation list (`createElement`, `destroyElement`, `appendChild`, `insertBefore`, `setStyle`, `setText`, `setEventListener`, `setRoot`, `setCustomProp`; `renderer.rs:6296-6335`).
  - Rust keeps a `RetainedTree` that `GpuixView::render()` turns into GPUI elements every frame.
  - Events go back as `(elementId, type)` through a `ThreadsafeFunction`. Handlers live in a JS registry.
  - On macOS it uses `gpui_macos::MacPlatform::new_embedded()` + `Application::run_embedded` + `platform.pump_events()` (`renderer.rs:1146-1205`) and "pumps AppKit on Node's main thread" (`AGENTS.md:1059`).
  - Much of its text, markdown and input code is ported from zeronsh/comet, the app zui was extracted for.

**7. GPUI bindings in other non-Rust languages.** All of them bind through FFI; I found no rewrite.
- **nakake/gpui-moonbit**:
  - A Rust staticlib `gpui-sys` with a cbindgen C header, 6,498 lines in `src/lib.rs`.
  - The tree is sent as an opcode byte buffer via `gpui_build_tree(view, ptr, len)`.
  - `gpui_run_window` **blocks inside GPUI's loop**.
  - Events come back through one fixed callback symbol, `dispatch_entry(abi_version, kind, view, a, b)` (5×i32), called only on the main thread (`docs/architecture.md` §4b, §11).
  - Text input and scroll state are kept in Rust maps keyed by id, outside the rebuilt tree.
- **fzdwx/gpui-react**: Bun FFI. GPUI runs on a spawned thread (`rust/src/renderer.rs:318-336`).
- **tension-atoi/shelly-gpui**: Zig backend with a Rust GPUI frontend.
- doeixd/gpui-ts is "inspired by gpui", JS only.

**8. Embedding precedent: aricarmo/godot-bend** (clone `.../c/eco/godot-bend`, Bend pinned at `0b7e2b11`)
- A Bend program becomes a GDExtension shared library:
  - `tools/build.sh` runs `bend main.bend -o main.c`, then `clang -shared -fPIC -Dmain=bend_cli_main -D_exit(c)=gd_exit(c)`.
  - `godot/godot.c` is pasted into that C file and calls runtime internals: `io_step`, `io_runs`, `corpus_setup`, `pool_stack`, plus a copied `io_wait` without the wait.
  - The effect `gd.frame` returns `IO_PARK` (`godot.c:611-615`). `_process` resumes it and runs `gd_pump_raw` (`godot.c:479-494`).
- "Godot never calls into Bend... a Bend program cannot be entered twice". Signals are queued and `Godot.signals()` drains them.
- Values cross through a Lua-style Variant stack, not Bend term layouts.
- Limits it reports: virtual methods cannot be overridden; 32-bit ints; F32 only; one program per library; the GPU `!` is untested; the runtime reserves 8 TB of address space and 2 GB per thread.
- 1,023 generated class files and 14,931 typed methods.

**9. Other Bend 2 UI and graphics apps**
- **i2cjak/backplane-bend** (★7; clone `.../c/eco/backplane-bend`): "a native window drawn entirely by Bend" (screenshot `docs/media/native-viewer.png` shows a T3Code-style sidebar, chat, input and a PCB viewer).
  - 91,425 lines of `.bend` and 11,339 lines of `.c`.
  - Its own X11 window effect `src/app/effects/win.c` uses dlopen'd libX11 and supports resizable windows, text, wheel, clipboard, drag/drop, focus, and damage-tracked present (only changed 64-px blocks are sent).
  - FreeType and fontconfig are dlopen'd in `src/gfx/effects/font.c`. stb_image is embedded in `img.c`. A Spleen bitmap font lives in pure Bend (`src/gfx/font.bend`).
  - Layout is pure Bend: `src/app/layout.bend` 192.8 KB and `nui.bend` 109.8 KB, with `Hit` regions for clicks.
  - Linux/X11 only for the native window; it serves a web client otherwise.
  - Its `AGENTS.md:85-140` "Bend traps" list is empirical cost data for a large UI app. Examples: `Bool.pick` evaluates both branches, so hidden screens still get laid out (70 ms); "an arity over 255"; no mutual recursion; non-tail recursion overflows; effects cannot build module constructor ids; #1007 slowdown in long-lived processes.
- **angerman/birc**: a terminal IRC client.
  - `Timui.frame(ui, List<DrawOp>, ...)`; C walks the Bend list (`src/bend/timui.bend`).
  - It declares a custom handle as `law Ui: Type` / `def Ui(): Window`.
  - It builds with its own clang command (`docs/FFI.md` "Build").
- **caiodomingues/bend-tui**: View tree, `render`, `Frame.diff`, `Tui.run`, with proven frame shape.
- **aivv73/bend-ui-test**: X11 input injection via a forked `Window.export_ref`.
- **kirillleventcov/bendirstat**: treemap.
- **PaschekSimon/bend-gui-experiment**: 7×9 pixel-font text input via Window.
- **benjamintd/bend-playground**: Bend compiled to JS plus "a small shared WebGL 2 display adapter".
- **AdrielSantana/bendcraft** and **AdrielSantana/metal-bending**: voxel game and benchmarks.
- Carolinewk/dugeonbend-temporary `src/Midum/*` (Button, Layout) dates from 2026-04, before Bend 2, so it is not Bend 2.

**10. BendHub**
- `https://hub.bend-lang.com/stats.json` returns `{"packages":486,"names":161,"authors":38}`.
- `search.json?q=` returns 0 results for gui, window, graphics, font, draw, canvas, widget, layout, svg, pixel, game, tui, gpu, raster and glyph.
- Nearest hits: `emerging-ezimg` (PNG/JPEG codec) and `bend-kit-tty` (ANSI/display width).
- There is no UI library on the hub.

**11. zui facts relevant to binding versus rewrite**
- 152,848 Rust lines (`crates/gpui` 75,141; `gpui_linux` 14,883; `gpui_macos` 14,045; `gpui_windows` 13,655; `gpui_wgpu` 5,792; `gpui_web` 3,010). `Cargo.lock` has 851 packages, including taffy 0.12.2, zed-font-kit, cosmic-text, swash, lyon, resvg, accesskit, wgpu/naga 29.0.4 and metal 0.33.
- Event listeners are shared multi-call closures. In `crates/gpui/src/elements/div.rs:575`: `on_click(listener: impl Fn(&ClickEvent,&mut Window,&mut App) + 'static)` stored as `Rc`.
- zui has `Application::run_embedded` / `ApplicationHandle` (`crates/gpui/src/app.rs:146-260`). But `MacPlatform::run` still calls blocking `app.run()` (`crates/gpui_macos/src/platform.rs:494-520`), and zui has no `new_embedded` or `pump_events`. gpuix gets those from its own fork.

### Flow
Five integration shapes exist in prior art:
1. **Bend owns the loop, Base Image path.** `App.run` → `view(S) -> (S, Image)` → `Window.frame(window, image)` → Metal kernel walks the heap quadtree (or X11/CUDA fill) → `List<Event>` → `tick`.
2. **Bend owns the loop, custom display-list effect.**
   - birc: `List<DrawOp>` walked in C.
   - backplane: a custom `Win.present/show(image, prev)` with damage tracking, plus FreeType glyph data returned as `List<U32>` and decoded in Bend.
3. **Host owns the loop, Bend embedded** (godot-bend). Emit C → compile as a shared library with `main` renamed → the host frame callback resumes the parked `frame` effect and pumps `io_runs` until the next park. Calls happen only from Bend to the host; host events are queued.
4. **Guest-language binding to GPUI.**
   - gpuix: reconciler → mutation batch → Rust RetainedTree → GPUI elements each frame → events by id. Pumped embedded on macOS, through a forked GPUI.
   - gpui-moonbit: whole-tree opcode buffer → GPUI owns the loop → a C callback into the guest.
5. **Bend as a JS module.** `bend x.bend -o x.mjs` → a JS host calls pure `view`/`update` → a DOM, WebGL (bend-playground) or gpuix host renders it.

Mapping onto Bend's constraints: shape 4's callback style (GPUI calls into Bend) has no Bend mechanism, because the C output has no exported defs (#813). A native Bend binding must therefore use shape 2 with an embedded, pumped GPUI, or shape 3 with GPUI owning the loop and Bend embedded the godot-bend way.

### Files Read
- bend-ui: `AGENTS.md`, `gpui-bend-research.md`, `bend-native-reconciler.md`, `bend-jsx.md` (all, in full).
- bend-over: `README.md`, `AGENTS.md`, `WISHES.md`, `papers/WISHES.md`, `packages/{browser-io,math-dsl}/WISHES.md`, `packages/browser-io/runner.js`, `demos/js-effects/{main.bend,web.bend,effects.js,LAWS.bend}`, `toolchain.json`, `packages/sqlite/{sqlite.bend (head),effs/sqlite.c (head),README.md (head)}`.
- Bend: `README.md`, `AGENTS.md`, `WONTFIX.txt`, `CHANGELOG.md` (head and grep), `guide/GUIDE.md:140-599`, `guide/EFFECTS.md`, `guide/SHADERS.md`, `bend2/base.bend:1-140`, `bend2/base.bend:330-400`, `bend2/effs/window.c` (full), `bend2/effs/window_*.js`, `bend2/effs/audio_*.js`, `bend2/main.ts:412-445`, `bend2/comp.ts:2722-2735`, `demos/app_slash_boss_3d/{README.md, bend3d.bend:1-80, 950-1140}`.
- Issues and PRs (body and comments): #1021, #1237, #923, #1022, #1019, #1020, #920, #813, #1148, #1029, #825, #921, #842, #1120, #1027, #846, #350, #874, #434, #885, #1144, #1106, #1007, #1307 (head); PRs #1108, #866 (full maintainer comment), #1272, #1115, #969.
- gpuix: `README.md:1-200, 405-530, 2395-2415`, `AGENTS.md:325-345, 1040-1090`, `packages/native/Cargo.toml`, `packages/native/src/renderer.rs:1130-1220` (plus greps).
- gpui-moonbit: `README.md`, `docs/architecture.md` (greps of §4b and §11).
- gpui-react: `README.md`, `rust/src/renderer.rs:318-339`.
- zui: `README.md`, `crates/gpui/Cargo.toml`, `crates/gpui/src/app.rs:140-275`, `crates/gpui_macos/src/platform.rs:480-520`, `crates/gpui/src/elements/div.rs:575-582`, tree listing and line counts.
- godot-bend: `README.md` (full), `tools/build.sh`, `godot/godot.c:1-40, 420-619`.
- birc: `README.md`, `src/bend/timui.bend`, `docs/FFI.md`.
- backplane-bend: `README.md`, `AGENTS.md:85-140`, `src/app/{nui.bend:1-60, win.bend, text.bend}`, `src/app/effects/win.c:1-40`, `src/gfx/effects/font.c:1-50`, `src/gfx/font.bend:1-40`, `docs/media/native-viewer.png`.
- Also read: READMEs of bend-tui, bend-ui-test, bendirstat, bend-gui-experiment, bend-playground, and shelly-gpui (grep).

### Boundaries
- **Foreign effect ABI**:
  - A def's body is `import "./x.c"` and/or `import "./x.js"`. JS-only is allowed; a missing `.c` errors only when building the C lane.
  - The `.c` file is pasted into the single emitted C file. It uses `CID(Name)`, `io_eff`, `io_cstr`, `io_str`, `io_hand`, `io_done`/`io_fail`, `io_work`/`io_wait_on`.
  - EFFECTS.md says "no ABI promise".
  - Arguments and results are Base types. Module constructor ids are path-qualified, so effects return `List<U32>` or strings and Bend decodes them (backplane trap).
- **Build flags are fixed** (`main.ts:422-445`):
  - macOS adds `-x objective-c -fobjc-arc -fmodules` when any `#import` is present, so system frameworks auto-link. Verified with CoreText below.
  - Linux adds `-lX11`/`-lasound` only when those headers are included.
  - There are no user link flags. A Rust GPUI/zui library therefore has to be `dlopen`ed (sqlite and backplane do this), or you emit C (`-o x.c`) and run clang yourself (godot-bend and birc do this).
- **Handles**: user handle laws must be filled with a Base handle type (`def Ui(): Window`). An unfilled one is "1 TODO found".
- **Proof gate**: any def that depends on foreign code makes `--check-only` print "SOME PROOFS FAIL / N defs rely on unsafe or foreign code" and exit 1. Laws have to target pure modules.
- **Concurrency and loop**: one event loop; a JS effect can park only on a descriptor or deadline, not on a Promise (#1148); no re-entry from the host.
- **Language**: closures cannot be stored in `Data` and are single-use in `Type` (verified). Numbers are Nat, U32, F32 only.
- **Distribution**: BendHub packages ship `.bend` + `.c` + `.js` + `LICENSE`, not native binaries (bend-over sqlite README).
- **Maintainer scope**: Base keeps only effects "no library can build"; extra GPU lanes are refused; the compiler is token-capped (`gates/repo.ts`: comp.ts 64k).

### Experiments Run
All were run in `research/c/exp` with `BEND_NO_TELEMETRY=1 bun ../bend/bend2/main.ts ...` (Bend 2.0.35 from source, bun 1.3.10, M3 Pro).
1. `ui_data.bend`: a pure `Msg`/`Node` Data tree with `update`/`view`/`fold`.
   - Output: `Column{[Text{"Count: 12"}, Button{"inc", "+", Inc{}}, Button{"dec", "-", Dec{}}]}`, real 0.10 s.
2. `ui_closure.bend`: `type Node is Data: Button{label: String, on: U32 -> U32}`.
   - Result: `SOME PROOFS FAIL ... expected : Data / observed : Type` at `on`.
3. `ui_closure_type.bend`: the same node as `is Type`, calling `f(f(x))`.
   - Result: `expected : f / observed : f (consumed more than once)`.
4. `win.bend` (the guide's `App.run` example):
   - `bend win.bend` (JS lane) prints `Window.open: no display (build a native binary ...)`, 0.07 s.
   - `-o win_native` builds in real 0.88 s, giving a 233,640-byte binary. Not run, to avoid opening a window.
   - `-o win.c` gives 5,019 lines / 130,842 bytes, with `int main` at line 4962 and 4 `#import` lines.
5. Slash Boss demo:
   - `--check-only`, real 0.21 s: `SOME PROOFS FAIL / Error: 4 defs rely on unsafe or foreign code: Play.loop, Play.run, Main.mode, main`.
   - `-o slash.c`, real 1.69 s: 122,215 lines / 3,343,013 bytes.
   - `-o slash_native`, real 12.05 s: binary 4,181,968 bytes plus `slash_native.gpu` 1,037,744 bytes.
6. `handle/main.bend`: `law Gpui: Type` / `def Gpui(): Window`, with a custom C+JS effect returning `io_hand(42)`.
   - JS and native runs both print `handle word seen by close: 42`. Native build took 0.33 s.
   - `--check-only` exits 1 with "3 defs rely on unsafe or foreign code".
   - Leaving the law unfilled (`open_law.bend`) gives `1 TODO found`.
7. `ct/main.bend`: a foreign `.c` with `#import <CoreText/CoreText.h>` measuring a string through `CTLineGetTypographicBounds`.
   - Native build took real 0.53 s. Output: `CoreText width x100: 12572`.
   - `otool -L` shows CoreText.framework linked with no user flags.
8. `ui_lib.bend -o ui_lib.mjs` (6,710 bytes), called from `host.mjs`.
   - Output: `{"$":"Column","kids":{"$":"Con",...}}` in 0.194 ms. Exports are `[update, view, fold, demo]`.
   - Lists must be passed as `{$:"Con",head,tail}`. A JS array crashed with `TypeError: undefined is not an object (evaluating '_m_0.$')`.

### Non-Obvious Things
- "gpuix" is itself a *binding*: about 26k lines of Rust plus a forked GPUI under a JS reconciler. "A gpuix for Bend" taken literally is Bend over a native GPUI, which conflicts with "fully written in Bend". zui is a source extraction of about 153k lines of Rust plus 851 crates (taffy, cosmic-text/font-kit, lyon, resvg, accesskit, wgpu).
- No one has rewritten GPUI in another language. Every non-Rust precedent (gpuix, gpui-react, gpui-moonbit) binds over FFI, and each needed either a patched GPUI loop (gpuix's `new_embedded`/`pump_events`) or a host callback into the guest (MoonBit's `dispatch_entry`). Bend has neither exported functions nor callbacks, and zui's macOS platform still blocks in `NSApp run`.
- The strongest "UI in Bend" evidence is backplane-bend: a real desktop UI drawn by Bend as an Image quadtree, with text from dlopen'd FreeType, damage tracking and pure-Bend layout. It is CPU/X11, not a GPU primitive renderer like GPUI's Metal/wgpu pipeline. Bend's own GPU path is just the `!` lane rasterizing into an `Image` (SHADERS.md: 8 ms at 1920x1200 on an M4 mini), and it is Metal/CUDA only.
- Base `Window` gaps that matter for a GPUI-class framework: no resize, no HiDPI, no typed text, no IME, no fullscreen, no clipboard, no cursor shapes, one window. The resize PR has sat unreviewed since 2026-09-27. Community repos work around this by writing their own window effect (backplane) instead of waiting for Base.
- Maintainers refuse anything they would have to maintain inside the compiler, such as extra GPU lanes, the web page target and library output. They prefer hub packages over foreign effects, and they say outright that the C internals have no ABI promise. godot-bend and birc already depend on pinned Bend commits for that reason.
- Writing foreign code makes `bend --check-only` and `bend PROOF.bend` fail unless the laws import only pure modules. Any binding design has to keep the law surface separate from effect modules.
- Long-running native processes slow down on repeated identical allocation (#1007, open, 3-17x; #1307 on 2.0.35). A framework that rebuilds trees every frame hits exactly this. backplane works around it by moving bulk work into child processes.
- `.c` effect files can be Objective-C on macOS, triggered by `#import`. That makes AppKit, CoreText and Metal reachable from Bend without custom flags. Linking a Rust staticlib is not possible without dlopen or a hand-run build.
- There is a cheap hybrid nobody has built yet: Bend `-o x.mjs` (pure model/update/view plus laws) driving `@gpuix/native`'s `applyBatch` from a small JS host. It would give real GPUI rendering today, but the host language is JS and Bend runs single-core there.

### Open Questions
- Do remorses/zed's `MacPlatform::new_embedded`/`pump_events` patches port cleanly onto zui? I could not inspect the fork's diff; GitHub code search does not index it.
- Does a dlopen'd Rust GPUI cdylib work inside a Bend binary on macOS? Two open points: whether AppKit/Metal run on the Bend loop thread, and whether the GPUI and Bend `!` lanes conflict over the Metal device (`window.c` reuses `gpu_dev`). Not tested.
- Will maintainers accept PR #1108 (resize/HiDPI) or text/IME events into Base, or push them to hub packages? There is no maintainer response yet.
- When the native library target (#813) arrives, will it allow host-to-Bend calls? That would make the gpui-moonbit-style callback design possible.
- I did not trace the per-frame cost of handing a large UI tree across the C boundary. Bend strings are linked lists, and `io_cstr` copies each one. No benchmark exists for GPUI-sized trees.