### Components Found

Checkout: `https://github.com/HigherOrderCO/Bend` at commit `565d7fd` (2026-10-04), `bend2/main.ts:33` `VERSION = "2.0.35"`, cloned to `.../scratchpad/b/bend`. My experiments are in `.../scratchpad/b/exp/*` and build outputs in `.../scratchpad/b/out`.

**Language and CLI**
- `bend2/bend.ts` is the human-written parser and checker. `bend2/comp.ts` holds the C/Metal/CUDA/JS emitters and both runtimes (the C runtime is the template `runtime_c` at line 3236). `bend2/main.ts` is the CLI. `bend2/base.bend` is the prelude.
- `bend2/effs/*.c|.js` are the effect implementations. Window is `effs/window.c` (847 lines) plus the JS stubs `window_*.js`. Audio is `effs/audio.c` plus `audio_*.js`.

**Window API** (`base.bend:373-395`)
- `Window.open(title, w, h) -> IO(Result<.., Window>)`
- `Window.frame(window, image: Image) -> IO(Window & Image & List<Event>)`
- `Window.set_title`, `Window.grab(window, Bool)`, `Window.close`
- Nothing else: no resize, HiDPI scale, cursor shape, clipboard, IME/text input, focus, position or fullscreen effects.

**Frame type**
- `type Image is Data: Pix{color: U32} | Qua{tl,tr,bl,br}` (`base.bend:74-76`). It is a quadtree over a 2^k square, k = ceil(log2(max(w,h))). Color is 0xRRGGBB, with no alpha: the macOS kernel writes alpha 1.0 (`window.c:382-383`) and Linux masks to `& 0xFFFFFF` (`comp.ts:4604`).
- The only drawing primitive is the pixel quadtree. There is no draw-primitive API.

**Events** (`base.bend:78-84`)
- `Key{code, down}`, `Mouse{x, y, button, down}`, `Move{x, y}`, `Look{dx, dy}`, `Scroll{x, y, dx: F32, dy: F32}`, `Close{}`.
- There is no Resize event, no text or IME event, no modifier state on mouse events, no timestamps and no click count.
- macOS key code is the first character of `charactersIgnoringModifiers`, lowercased, else `65536 + keyCode`. Modifier keys arrive as Key events via `flagsChanged` (`window.c:70-89`).

**App helper** (`base.bend:120-121`, `2935-3009`)
- `App<S>{view: S -> Pair(S, Image), tick: List<Event> -> S -> IO(Maybe<S>)}`.
- `App.run` calls `App.loop` with fuel `4294967295n` (`base.bend:2973-2986`). `App.turn` drops the previous image with `Image.drop!(image)` (`base.bend:2954`), so every `App.run` program has `BANGS 1` and builds a `.gpu`.
- `App.play` folds scripted event frames headless, for tests (`tests/gfx/app_play.bend`).

**Audio** (`effs/audio.c`)
- `Audio.open(rate)` → `Audio.write(audio, List<&2, F32>) -> IO(Audio & U32 queued)` → `Audio.close`.
- Backing store is a 4096-frame float32 stereo ring. macOS uses an AudioToolbox DefaultOutput AudioUnit whose render callback (`io_ring_pump`) drains the ring. Linux uses ALSA with a pump thread doing `snd_pcm_writei` 256 frames at a time. A write past the ring's room is dropped. The JS lane is a silent clock stub.

**Handles** (`base.bend:94-109`)
- `law File/Socket/Listener/Window/Audio: Type` are opaque and linear, packed into one word by `io_hand(v)` / `io_hand_v(t)` (`comp.ts:5311-5312`).
- User code cannot define a new handle type (WONTFIX #825). A custom effect has to reuse a Base handle type.

**Collections**
- `Array<T>` is `Type`, so it has exactly one owner. It is stored as one flat block (`comp.ts:4056-4160`): TAG_ARR for 2^c Terms, TAG_BUF for 2^c packed u32 words.
- An all-scalar record element is packed inline at a power-of-two stride (`lay_arr`, `comp.ts:1008-1011`; layout comment at `930-936`).
- `Map<a, V>` is string-keyed only (a trie on key bits, `base.bend:86-89`, `2440-2871`), with `Set` built on it. There is no integer-keyed map.

### Flow

**1. Compile pipeline** (`main.ts:340-445`)
1. `bun bend2/main.ts f.bend -o bin` parses and checks (`bend.ts`).
2. `Comp.compile_book` (`comp.ts:2748`) emits one C file. It reads every reachable foreign def's `.c` once and splices it after the runtime (`effect_srcs`, `comp.ts:2722-2735`; placement `${reqs}` at `comp.ts:5917`).
3. The C file goes to `mkdtemp` and is built by `cli_build` (`main.ts:422-445`):
   - The compiler is `$CC`, `clang` or `clang-NN`, at least clang 14, or 19 (Apple 17) when the program has `!` (`cc_find`, `main.ts:386-414`).
   - On macOS, a `!` program or any spliced `#import ` line switches to `-x objective-c -fobjc-arc -fmodules`. Frameworks then autolink.
   - On Linux, only `-lX11` and `-lasound` are added, and only when their headers appear.
   - Flags are `-std=c11 -O3 ... -lpthread -lm`. There is no CFLAGS or LDFLAGS hook.
   - When `#define BANGS` is not 0, the binary runs once with `--gpu-build` to write `<bin>.gpu`. On macOS that is a Metal binary archive of the same C source compiled as MSL via `newLibraryWithSource:@(BEND_SRC)` (`comp.ts:4855-4888`). The `.gpu` file must stay beside the binary.
4. `bend f.bend` with no `-o` runs an IO `main` on the JS lane in-process (`main.ts:854-855` → `comp.ts:1294-1298`, `new Function(...)`). So no window opens.

**2. Runtime event loop** (`comp.ts:5831-5912`)
- `main()` (`5922-5977`) runs `io_loop` on the process main thread, which keeps AppKit happy.
- An IO action is a CPS term. `corpus_eval` evaluates `cont(item)` (pure work is parallel on the CPU pool, or on the GPU for a bang) until it yields a request: a constructor whose CID is the foreign def.
- `io_step` dispatches through `io_eff_rows[cid].run(e, fields, w)`.
- A request with need 0 runs inline, and `io_step` loops (`5863-5867`). It does not return to the scheduler until the computation parks on `IO_READ`/`IO_TIME`, a channel or a helper-thread job (`io_work`, up to `IO_HELP`=64 threads, `5612-5629`).
- Parked fds and timers are checked by `select` only when the run queue is empty, or every 64 loop iterations (`5899-5909`).

**3. One frame on macOS** (`window.c:491-499`)
1. `window_frame` → `io_sync` → `window_show` (`449-489`).
2. `window_corpus` wraps the whole Bend heap as an `MTLBuffer` via `newBufferWithBytesNoCopy:e.mem` (`425-447`), or reuses `gpu_buf`.
3. A helper GCD thread takes `[layer nextDrawable]` and dispatches the compute kernel `window_dev` (MSL source inline at `359-384`). The kernel walks the Image quadtree straight out of the Bend heap per pixel and writes the drawable texture. It then calls `presentDrawable` and `waitUntilCompleted`.
4. Meanwhile the main thread runs `window_wait` (`408-423`), pumping `NSApp nextEventMatchingMask/sendEvent`.
5. `BendView` handlers append 5-u32 records `(cid, a, b, c, d)` to an `NSMutableData` (`65-68`). They become a `List<Event>` via `window_list` (`331-337`).
6. Layer settings: `CAMetalLayer` with `BGRA8Unorm`, `displaySyncEnabled = YES`, `maximumDrawableCount = 2`, `drawableSize = (w, h)` (`226-232`). The style mask has no `Resizable` (`214-216`). There is no `[NSApp run]`: Cocoa is pumped only inside `Window.frame`.
7. Result: GPU display of the quadtree, zero copy on unified memory, vsync-paced. There is no CPU blit on macOS.

**4. One frame on Linux** (`window.c:246-281`, `549-692`)
- One X11 `Display` per window and a `Display*` to `XCreateImage` 32-bit buffer.
- Window size is fixed by `XSizeHints` min = max (`270-272`).
- Events are pumped per frame by `XPending`/`XNextEvent` (`549-596`).
- Pixels: on the CPU via `window_sq`, or with CUDA via the `window_dev` kernel plus `cuMemcpyDtoH` (`629-657`). Then `XPutImage` (`670-682`).
- Frame pacing is a 60 Hz `nanosleep` (`window_pace`, `660-668`), not vsync. There is no GL or Vulkan.

**5. Bang (`f!(x)`) dispatch** (`corpus_eval`, `comp.ts:5247-5286`)
- Only when the root task of an evaluation is a bang segment (`fid_bangs`) and `io_gpu` is set: `ring_push` → `cube_run(H, true)` → `task_deliver` hands the result term back into the continuation.
- The result is ordinary heap terms in unified memory (`MTLResourceStorageModeShared`, `gpu_load`, `comp.ts:4911-4924`).
- The device program contains only segments reachable from bangs (`dev = reach(...)`, `comp.ts:2795-2797`, `2868`).

### Files Read

- Docs:
  - `guide/GUIDE.md`, in full (677 lines)
  - `guide/EFFECTS.md`, in full
  - `guide/SHADERS.md`, in full
  - `README.md`, in full, including limitations at lines 219-256
  - `AGENTS.md` and `WONTFIX.txt`, in full
  - `CHANGELOG.md`: head, the relevant entries, and the release list. 2.0.0 shipped 2026-09-17; 35 releases in 17 days.
- Window and Audio effects: `bend2/effs/window.c` in full; `window_*.js`; `audio.c` (first 120 lines); `audio_*.js`
- Other effects: `spawn.c`, `chan.c` (head), `now.c`, `sleep.c`
- `bend2/base.bend`: lines 1-560, 1540-2070, 2240-2440, 2900-3009, plus the section index
- `bend2/comp.ts`:
  - emitter, foreigns and compile: 926-1015, 1166-1300, 1700-1770, 2700-2890
  - runtime dialect: 3236-3365
  - heap, tags and arrays: 3900-4160
  - window and GPU: 4580-4630, 4795-4970
  - IO loop, run and main: 5225-6024
- `bend2/bend.ts`: 2425-2505 (foreign `import` parse) and 3850-3881 (foreign must return base IO)
- `bend2/main.ts`: 1-219 and 340-520
- Demos and tests:
  - `demos/app_pong_game_2d/main.bend`, `demos/app_triangle_2d/main.bend`
  - `demos/app_slash_boss_3d/README.md`, `main.bend` (outline, 2540-2880, 3200-3221), `bend3d.bend` (head, 1440-1554)
  - `demos/app_win_is_bug_2d/README.md`, `web/*`
  - `tests/gfx/*` (4 files)
  - `tests/io/foreign_types.*`, `far_types.*`, `foreign_shared.*`, `main_foreign.*`, `foreign_arrow_arity.*`

### Boundaries

**(1) Window**
- The API is a whole-frame pixel quadtree in and an event batch out, once per frame.
- No draw primitives. No HiDPI: I measured `backingScaleFactor 2.0`, `contentsScale 1.0`, `drawableSize 512x512` for a 512-pt window, so it renders at 1x and is upscaled. Mouse coordinates are in points, clamped to the drawable (`window.c:91-96`).
- Not resizable. No text input or IME.
- Multiple windows work on macOS. I measured two windows framed alternately: 240 rounds in 2310 ms, about 104 Hz each.
- vsync: macOS uses `displaySyncEnabled`; Linux paces to 60 Hz with sleep.
- Max size is 16384 per side (`window.c:192`).
- JS lane: `Window.open` always answers Fail ("no display", code 45 on darwin), and the frame is a no-op (`window_open.js`, `window_frame.js`).

**(2) Foreigns (FFI)**
- Syntax: a def whose body is `import "./x.c"` plus `import "./x.js"` (`bend.ts:2465-2481`; `GUIDE.md:406-415`, `589-591`).
- It must return base `IO(...)` directly, else "a foreign definition returning base IO(...) directly" (`bend.ts:3863-3872`). There are no pure foreigns, and a foreign cannot be `main` (`comp.ts:1288-1289`).
- The C side is spliced into the program's C file with every runtime symbol in scope. It registers with `io_eff(CID(Name), run, need)`. `run` receives `Term* f` (all arguments boxed, `comp.ts:1186-1187`). The marshalling helpers are listed in Non-Obvious Things.
- What crosses: U32 as a raw word; String as a UTF-8 copy (consumes the list); `List<&2, U32>` as bytes; any program datatype built or walked with `term_pak`/`io_node`/`term_peek` and `CID(Ctr)` (`tests/io/foreign_types.c`); Array in place (my experiment); Base handles as opaque words.
- Arbitrary C works, including ObjC and frameworks on macOS. Verified: CoreText from a foreign effect, plus a custom effect that reaches Base's `NSWindow` and `CAMetalLayer` through `io_hand_v`. `gpu_dev` and `gpu_que` are static globals a foreign could reuse (`window.c:200`, `390`).
- C calling back into Bend is not a supported feature. Cocoa-style callbacks are avoided by queuing in C and returning batches. I did get a C effect to apply a Bend closure synchronously by re-entering `corpus_eval` with a `Clo~apply` task, copying `io_step` (`exp/cb`: printed `callback result: 1042` on both lanes). That relies on internals with "no ABI promise" (`EFFECTS.md`, "Compatibility"). The closure is affine, so one call. It is only possible while an effect holds `Env e`.
- Foreigns never run on the GPU: "Only the event loop runs them" (`GUIDE.md:408-409`).
- Linking: frameworks autolink only in ObjC mode. Non-framework libs do not link: `#pragma comment(lib,"z")` failed on macOS. A `CC` wrapper that appends `-lz` worked. On Linux, only X11 and ALSA are linked.

**(3) State**
- Values are affine by default. `Data` types can be shared with `+`, which costs a refcount, and on the device an atomic per read.
- Closures are affine, "called at most once" (`GUIDE.md:83-85`). Verified:
  - calling `f(f(s))` fails with "f (consumed more than once)"
  - `type Button is Data: Button{.., on_click: U32 -> U32}` fails with "expected Data, observed Type"
  - a defunctionalized `Msg` ADT in a `Data` Button, dispatched by a top-level `update`, works (printed `10`)
- Long-lived app state is a value threaded through `view` (which must hand it back beside the image) and `tick`. A linear `S: Type` is allowed (`tests/gfx/app_linear.bend` threads a `File`).
- In-place update: `a[i] <- v` for `Array<U32>`; `Array.set`/`swap`/`get`/`clone` for others. Sizes are powers of two, indexes wrap.
- An Array cannot go down a fork tree (`SHADERS.md:155-156`). `Array.fork`/`join` and atomics need `@unsafe` (`base.bend:2301-2367`).
- A retained widget tree has to be a persistent `Data` ADT, rebuilt per update. Handlers have to be data, not closures.
- No traits or type classes, so GPUI's Element/Render traits become a closed sum or `~` templates, which are compile-time and closed (`GUIDE.md:262-277`).
- No mutual recursion without `@unsafe` (`GUIDE.md:113-121`). I hit this: a def cannot call one written below it.

**(4) IO and the event loop**
- `do IO<T>:` desugars to `IO.bind`/`IO.pure` (`GUIDE.md:350-415`, `434-437`).
- `IO.spawn`, `IO.fork`/`IO.join`, `Chan.new/send/recv/close` (`base.bend:205-262`). The program ends when every computation is done, and reports a deadlock when all of them wait.
- Interactive loops in the repo:
  - `App.loop`, fuel-bounded (`base.bend:2973-2979`)
  - Slash Boss `Play.loop`, `@unsafe` and unbounded, with per-frame `IO.now`, `Window.frame`, `Window.set_title` for FPS and `Audio.write` (`demos/app_slash_boss_3d/main.bend:2757-2843`)

**(5) Numerics and text**
- Only Nat, U32, F32 (`README.md:230`). Nat is an immediate up to 2^48-1 (WONTFIX #779). U64 and F64 are "SOON" (WONTFIX), and Metal has no f64. F32 math is axiomatic `law`s (`base.bend:1548-1707`).
- `String = SNil | SCon{Char, String}`, one heap node per char (`io_str`, `comp.ts:5511-5547`).
- `File.read_bytes` and `File.read_at` answer `List<&2, U32>`, one cons per byte (`base.bend:274-282`).
- There is no byte type. The closest packed buffer is `Array<U32>`/`Array<F32>` as TAG_BUF (2^c u32), and packed scalar records in arrays.
- Implications:
  - TrueType or OpenType parsing in Bend needs manual sign extension for i16/F2Dot14 and has no 64-bit intermediates.
  - Shaping via HarfBuzz or CoreText is reachable only as IO effects, so a pure layout pass cannot call a text measurer. Measure in IO first, or load metric tables once and look them up purely.
  - Glyph rasterization in pure Bend is plausible on F32. Slash Boss renders HUD text as quads (`SHADERS.md:114-116`).

**(6) GPU via `!`**
- The whole language runs on the device as one compute kernel `bend_dev` (MSL or CUDA). There is no graphics pipeline, no texture sampling and no blend hardware.
- Constraints:
  - goes to the GPU only at the root of an IO step; inside CPU-parallel work it runs on the CPU (WONTFIX #1065)
  - a cube of 16384 lanes (128 x 128); launch fee about 0.4-0.5 ms
  - balanced binary fork-join
  - non-tail recursion works but uses heap frames and is slow
  - default heap cap 2 GB on Metal (`gpu_span`, `comp.ts:4904-4909`), override with `--gpu 4GB`
  - one GPU per program
- Results return as heap terms, with zero copy on Apple.
- Once per frame is the intended pattern: Slash Boss bangs once per frame (`bend3d.bend:1549-1553`).
- GPU code cannot call effects.

**(7) Toolchain**
- One C file per program and a single `main`. There is no library target yet (WONTFIX "SOON" #813). The compiler is clang only.
- JS target: sequential, one core, no graphics or audio. `-o x.mjs` exports non-IO defs, and `bend page.html -o dist` bundles a web page that imports `.bend`. `demos/app_win_is_bug_2d/web` draws on a canvas from JS calling pure Bend defs.

### Experiments Run

All runs used `export TMPDIR=<scratch>/b/tmp BEND_NO_TELEMETRY=1` from `<scratch>/b` (or from `bend/` where noted), with no global installs. Toolchain: bun 1.3.10, Apple clang 21, Xcode `metal` present, M3 Pro.

**Demos and builds**

| Program | Command | Build time | Result |
|---|---|---|---|
| hello world | `bun bend2/main.ts demos/io_hello_world/main.bend` (no `-o`, from `bend/`) | 0.19 s | printed "Hello, world!" |
| hello world | same with `-o ../out/hello` | 0.29 s | binary 68.7K; C is 2960 lines, 74 KB |
| triangle | `-o ../out/tri` (emit to `.c` alone: 0.12 s, 5949 lines, `BANGS 1`, includes `#import <AppKit/AppKit.h>`) | 1.87 s | `tri` 261K plus `tri.gpu` 95K. `perl -e 'alarm 4; exec @ARGV' ./tri` exited 142 (killed by SIGALRM after 4 s); the window ran with no crash |
| pong | `-o out/pong` | 0.99 s | ran 3 s, killed (exit 142). `PROOF.bend` checked in 0.10 s |
| pong, JS lanes | no `-o`, and `-o out/pong.js` run with `bun out/pong.js` | n/a | both print "Window.open: no display ..."; the JS run exits 45 |
| Slash Boss 3D | `-o out/slash.c` | 1.56 s (Bend to C) | 122,215 lines, 3.3 MB |
| Slash Boss 3D | `-o out/slash` | 12.95 s total | binary 4.0 MB, `slash.gpu` 1.0 MB |
| Slash Boss 3D, split | `clang -x objective-c -fobjc-arc -fmodules -std=c11 -O3 -DBEND_METAL=1 slash.c ...`, then `./slash2 --gpu-build` | 8.12 s clang, 1.88 s Metal archive | — |

Slash Boss headless probe: `SLASH_PROBE=600 ../out/slash` (from `bend/`) printed `frames 592 build 2037 draw 6180 tick 349 mix 6 whole 8579`. These are medians in µs at 1920x1200, about 116 FPS. The M4 mini figure the guide quotes is 8.0 ms.

**My own programs**

- `exp/fps`: a full-detail 512x512 gradient quadtree (262,144 leaves) every frame. Build 0.92 s.
  - 180 frames: 1981 ms.
  - 600 frames: 5349 ms; with `--threads 1`: 5232 ms; with `--gpu off`: 5204 ms.
  - About 8.0 ms per frame, which is vsync on this display.
- `exp/big` and `exp/bigg`: 1920x1200 window, k=11 full quadtree (about 4.2M leaves per frame), 180 frames.

  | Variant | Default | `--gpu off` | `--gpu on` | `--threads 1` |
  |---|---|---|---|---|
  | `grad` (CPU parallel) | 3290 ms (about 18 ms/frame) | — | — | 22234 ms (about 123 ms/frame) |
  | `grad!` (bang in view) | 1901 ms | 1701 ms | 1734 ms | — |

  The bang variant is vsync-capped, so these numbers do not show whether its bang actually ran on the GPU.
- `exp/ffi`, built in 1.38 s:
  - CoreText width ×1000 = `143179` ("Hello, GPUI in Bend", Helvetica 16)
  - an `Array<U32>` of 1024 read in place from C summed to `523776`, correct; the emitted C uses `blk_new(e, 0, 10ull, ...)`, which is a packed BUF
  - 1e6 trivial foreign round trips took 26 ms, about 26 ns each
- `exp/conc`: `IO.spawn` a ticker doing 10× `IO.sleep(50)` beside `App.run` for 120 frames.
  - Output: "frames done", then `tick gap ms 1699`, then nine gaps of about 51 ms. The ticker was starved for the whole app run.
  - `exp/conc2`: adding `IO.sleep(0)` per tick gave gaps of 611 (window startup) then 50-58 ms, running concurrently.
- `exp/two`: two windows, 240 alternating rounds in 2310 ms.
- `exp/win`: a user effect on Base's `Window` handle printed `backingScaleFactor 2.0 contentsScale 1.0 drawableSize 512x512 bounds 512x512`.
- `exp/openclose`: `Window.open` plus `Window.close` with no `Window.frame` fails to build on macOS: `use of undeclared identifier 'CID_KEY'` / `'CID_MOUSE'`. `BendView` references Event CIDs that are not emitted.
- `exp/lib` (zlib):
  - `#include <zlib.h>` failed because the runtime's `#define FAR static __attribute__((noinline))` clashes with zconf.h.
  - With `push_macro("FAR")` / `#undef` it compiles, but linking fails: "Undefined symbols". Adding `#pragma comment(lib,"z")` did not help.
  - `CC=exp/lib/cc-wrap`, a script that runs clang and appends `-lz`, built and printed `zlib 1.2.12`.
- `exp/clo`: closure and handler tests, results under Boundaries (3).
- `exp/cb`: the callback hack, results under Boundaries (2).

### Non-Obvious Things

- **`Window.frame` blocks the event loop.** It is a need-0 effect, and need-0 effects run inline inside `io_step`'s loop (`comp.ts:5863-5867`). An app that never parks starves every other computation (timers, TCP, channels) until it exits. Measured: 1699 ms with no tick. The workaround is a parking effect per frame such as `IO.sleep(0)`.
- **`!` is easy to lose.** It is GPU only at the root of an IO evaluation (WONTFIX #1065). Per `SHADERS.md:126-128` and `204-205`, a bang after host forks in the same evaluation runs on the CPU pool, and a bang inside a `do` continuation flips borrowing to owning, about 2× slower. Slash Boss puts an `IO.now()` seam before the bang (`main.bend:2829-2835`).
- **Every `App.run` program builds a GPU program.** `App.turn` calls `Image.drop!` (`base.bend:2954`), so these programs need clang 19 or Apple clang 17 and ship a `.gpu` file beside the binary.
- **Frame drops cost real time.** Freeing a whole Image on the host "costs milliseconds" (`SHADERS.md:228-230`). Slash Boss hands the previous frame back into the next bang and sinks it tile by tile.
- **Base names leak into foreign C.** Foreign C is spliced after a runtime that defines short global names (`FAR`, `INLINE`, `DEV`, `u32`, `TAG_*`, ...). Third-party headers can collide with them, as zlib did with `FAR`.
- **Handle type and closure-type quirks.**
  - A custom handle type is impossible (WONTFIX #825), so a custom renderer reuses `Window` and so on.
  - A `+x` parameter makes a different function type (WONTFIX #1111). `App{view, tick}` rejected my `def view(+n: U32)`.
- **Effect plumbing is per-program and unstable.** Effect `.c` and `.js` files are spliced only when reachable (`#ifdef CID(Window.open)` guards). `EFFECTS.md` says the C names are runtime internals: "no ABI promise. Rebuild your effects with every update."
- **Language syntax limits.**
  - `match` only on parameters or pattern-bound variables, never on computed values.
  - No `if`.
  - Destructuring `(a, b) = r` is rejected inside a `do` block. I hit this and had to use a helper.
  - Annotations are often required, for example `{Button{..} : Button}`.
- **Array limits.** Arrays have one owner and cannot cross a fork tree. `SHADERS.md:155-156` says "build lists" for per-tile data going to the GPU. An unbalanced `ALeaf`/`ANode` tree fail-stops at runtime (WONTFIX #808).
- **The C runtime's memory model.** It has no C stack and no GC: a `match` frees the node it opens on the spot, and only `+` values carry refcounts (`GUIDE.md:639-651`). A `+` on a type "heats" every node of that type, adding counts and atomics on the device (`SHADERS.md:183-213`).
- **Scale of the project.** The README says the compiler "is 99% AI-written and not yet fully audited". It is two and a half weeks past 2.0.0, with 35 point releases.

### Open Questions

- Whether `grad!` inside `view` actually ran on the GPU. Timings were vsync-capped with `--gpu on` and `--gpu off` alike. A heavier non-vsync probe, or instrumenting `cube_run(H, true)`, would settle it. Also untested: why the bang-free `grad` variant was about 2× slower than the bang variant with `--gpu off`.
- Behaviour on Linux and X11 and on CUDA. I traced it from source only; nothing was run.
- Whether the `corpus_eval` re-entry callback hack is safe under real conditions: with the multi-thread pool busy, inside Cocoa callbacks fired during `window_wait`, or when the callback forks or bangs. Only a trivial case was tested.
- Whether a foreign Metal render pipeline can read the Bend heap through `gpu_buf`/`window_buf` while the bang runtime uses the same buffer and queue, as `window.c` does for its compute kernel. Hazard tracking is "Untracked" (`window.c:440`, `comp.ts:4914`). Not tested.
- Throughput of large `List<&2, U32>` byte transfers (font files) and of String-heavy layout in the C lane. Not measured.
- Roadmap. HiDPI, resize, text input and a library target (#813, "planned, not scheduled") are not committed anywhere I found. U64 and F64 are listed as "SOON".