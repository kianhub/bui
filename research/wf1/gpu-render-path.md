### Components Found

**zui** (cloned to `scratchpad/d/zui`, HEAD `667d0aa`, 2026-09-30)
- `crates/gpui/src/scene.rs`
  - `Scene` (l.41-57) holds per-kind `Vec`s: `shadows`, `quads`, `paths`, `underlines`, `monochrome_sprites`, `subpixel_sprites`, `polychrome_sprites`, `surfaces`, plus `backdrop_blurs`, which sit outside the batch stream.
  - `insert_primitive` (l.114) gives each primitive a `DrawOrder` from `BoundsTree`. `finish()` (l.179) sorts each kind by order.
  - `BatchIterator` (l.300-510) merges the kinds into `PrimitiveBatch` runs. Sprite runs also break when the atlas texture changes.
  - Primitive structs are `#[repr(C)]` instance records: `Quad` (l.613: bounds, content_mask, `Background`, border color, per-corner radii, per-edge border widths, `EdgeFadeParams`), `Shadow` (l.669: blur_radius, inset, element bounds), `MonochromeSprite`/`SubpixelSprite` (l.806/826: `AtlasTile` plus a 2x2 transform), `PolychromeSprite` (l.846: grayscale, opacity, corner radii, `ImageAlphaMaskParams`), and `Path` (l.965: a triangle list with quadratic `st` coordinates).
- `crates/gpui_macos/src/metal_renderer.rs`
  - `draw_frame` (l.573): `next_drawable`, then `draw_primitives_to_texture` (l.950), then `present_drawable` and `commit`. The CPU does not wait for the GPU here. The instance buffer is returned in a completion handler.
  - Paths go through a separate render pass into an intermediate texture with 4x MSAA (`PATH_SAMPLE_COUNT = 4`, l.44), then get composited (`draw_paths_from_intermediate`).
  - For each backdrop blur, the renderer ends the encoder, blits a padded framebuffer region, runs an MPS Gaussian kernel (`ensure_gaussian_kernel`, l.1474), and reopens the pass with `Load` (l.1001-1103).
- `crates/gpui_macos/src/shaders.metal` (1377 lines)
  - `quad_fragment` (l.101): rounded-rect SDF, borders (including dashed), gradients, edge fade.
  - `shadow_fragment` (l.504): four samples of `blur_along_x` using an `erf` approximation (l.1122-1138).
  - `monochrome_sprite_fragment` (l.668): linear sample of the A8 atlas.
  - `path_rasterization_fragment` (l.796): quadratic-curve coverage using `dfdx`/`dfdy`.
  - Also `polychrome_sprite_fragment`, `surface_fragment` (YCbCr) and `backdrop_blur_fragment`.
  - `crates/gpui_wgpu/src/shaders.wgsl` (1590 lines) is the WGSL twin.
- Glyph path:
  1. `Window::paint_glyph` (`crates/gpui/src/window.rs` l.4311) quantizes the origin to a subpixel variant.
  2. It calls `sprite_atlas.get_or_insert_with(params, || text_system.rasterize_glyph(..))`.
  3. On macOS, `rasterize_glyph` (`crates/gpui_macos/src/text_system.rs` l.436) draws through a CoreGraphics `CGContext` bitmap (A8, or RGBA for emoji).
  4. `metal_atlas.rs` allocates the tile with `etagere::BucketedAtlasAllocator` and uploads it with `replace_region` (l.246-253) into an `A8Unorm` or `BGRA8Unorm` texture (l.163/167).
  5. A `MonochromeSprite{tile}` goes into the scene.

**Bend 2** (cloned to `scratchpad/d/bend`, HEAD `565d7fd`, 2026-10-04, `VERSION = "2.0.35"` in `bend2/main.ts`)
- `bend2/base.bend`
  - `type Image is Data: Pix{color: U32} | Qua{tl,tr,bl,br}` (l.74).
  - `type Event`: Key, Mouse, Move, Look, Scroll, Close (l.78).
  - `law Window: Type`, an opaque linear handle (l.105).
  - `App{view: S -> Pair(S, Image), tick: List<Event> -> S -> IO(Maybe<S>)}` (l.120).
  - `Window.frame(window, image) -> IO(Window & Image & List<Event>)` (l.378).
  - `App.turn` drops the previous image with `Image.drop!(image)`, which is itself a GPU bang every frame (l.2947).
  - `@unsafe Array.fork` / `Array.join` (l.2306-2312) and the `Array.atomic.*` laws.
- `bend2/effs/window.c` (846 lines), the only presentation path in Base.
  - macOS `window_make` (l.190): `CAMetalLayer`, `BGRA8Unorm`, `drawableSize = (w,h)`, `displaySyncEnabled = YES`, `maximumDrawableCount = 2`. The style mask has no Resizable flag.
  - `window_msl` (l.359): a compute kernel `window_dev` that walks the quadtree once per pixel from the root, reading the Bend heap directly, and writes `float4(c.zyx, 1.0)`. Alpha is forced to 1.
  - `window_corpus` (l.425) reuses `gpu_buf` when the GPU is on. Otherwise it wraps the heap prefix with `newBufferWithBytesNoCopy`.
  - `window_show` (l.449) gets `nextDrawable` on a helper thread, dispatches, presents, calls `waitUntilCompleted`, and pumps NSEvents meanwhile (`window_wait`, l.408).
  - On Linux: `window_sq` (l.606) fills the XImage by CPU recursion, then `XPutImage`, paced to 60 Hz by `window_pace` (l.660).
- `bend2/comp.ts`, which holds the runtime and both emitters:
  - `gpu_run` (l.4830): up to 4 dispatches. A seed grow uses 1 group if `f < 128`; a grow uses 128 groups if `f < 16384`; the work pass uses 128x128 lanes; a final pass uses 1 group.
  - `gpu_span` (l.4904): `min(recommendedMaxWorkingSetSize, maxBufferLength, 2 GB)`.
  - `gpu_load` (l.4911): `newBufferWithBytesNoCopy` over the host mmap, `StorageModeShared` and `HazardTrackingModeUntracked`. It loads the binary archive `<bin>.gpu`, or compiles it.
  - `gpu_kernel` (l.4941): adds `memoryBarrierWithScope` between dispatches.
  - `gpu_pass` (l.4951): one command buffer, then `commit`, then `waitUntilCompleted`.
  - `cube_run` (l.5129): loops passes until the root delivers.
  - `corpus_eval` (l.5247): a bang task is detached, its continuation is set to HOLE, it is pushed to ring 0, and `cube_run(H, true)` runs.
  - `SHIMS` (l.313) maps `sqrt` and others to `precise::`. `#pragma clang fp contract(off)` is at l.3245.
  - `window_pix` (l.4595) is the quadtree walk used on Linux and CUDA.
- `bend2/main.ts` `cli_build` (l.422) runs `clang -x objective-c -fobjc-arc -fmodules -std=c11 -O3 [-DBEND_METAL=1] file.c` and then `./bin --gpu-build`. There is no hook for extra link flags.
- `guide/SHADERS.md` is the reference rasterizer recipe, from `demos/app_slash_boss_3d/bend3d.bend`: 1920x1200 at 120 FPS, 8.0 ms per frame on an M4 mini.

### Flow

**zui frame**
1. Elements paint into `Scene` (`insert_primitive`).
2. `finish()` sorts each kind.
3. `MetalRenderer::draw`: `next_drawable`, then one command buffer.
4. For each `PrimitiveBatch`: instanced draw. Paths get their own MSAA pass; blurs break the pass.
5. `present_drawable` and `commit`, with no wait.
6. Text: `paint_glyph`, then the atlas cache (on a miss, CoreText rasterizes and uploads to the texture), then a sprite instance whose fragment shader samples the atlas.

**Bend `!` call**
1. A marked call met at the root of an IO step (WONTFIX #1065: only there) has its task detached in `corpus_eval`.
2. `ring_push(H, 0, t)`, then `cube_run(H, true)`, then `gpu_pass(f)`. That is one MTLCommandBuffer holding the grow/work dispatches of the persistent `bend_dev` kernel, compiled from the same C source and embedded in the binary.
3. `waitUntilCompleted`. Passes repeat until the root delivers.
4. The answer goes into the original continuation and the CPU continues. The CPU and GPU never compute at the same time.
- Memory: one corpus (header, 2^14 rings, lane stacks, heap). CPU and GPU see it at the same addresses through a zero-copy buffer.
- Metal's span is fixed before the first dispatch (2 GB default) and cannot grow while a kernel is running.

**Bend frame through Base (`App.run`)**
1. `view(state)` builds an `Image` quadtree (pure; possibly `!`).
2. `Window.frame`: `io_sync`, then the `window_dev` kernel walks the tree per pixel into the drawable.
3. Present and `waitUntilCompleted`.
4. Events collected since the last frame are returned.
5. `App.turn` runs `Image.drop!(image)` (a second bang), then `tick`.

### Files Read
- zui:
  - `README.md`
  - `crates/gpui/src/scene.rs` (all)
  - `crates/gpui_macos/src/metal_renderer.rs` (l.39-650, 950-1220, function index)
  - `crates/gpui_macos/src/shaders.metal` (function index, l.101-200, 504-563, 668-684, 796-837, 1087-1140)
  - `crates/gpui/src/window.rs` (l.4311-4386)
  - `crates/gpui_macos/src/text_system.rs` (l.198-253, 436-473)
  - `crates/gpui_macos/src/metal_atlas.rs` (index)
- Bend:
  - `README.md`, `AGENTS.md`, `WONTFIX.txt`
  - `guide/GUIDE.md`, `guide/SHADERS.md`, `guide/EFFECTS.md`
  - `paper/BendRT.pdf` (all, via pdftotext)
  - `bend2/effs/window.c` (all), `window_*.js`, `audio.c` (l.187-219)
  - `bend2/base.bend` (l.1-140, 1548-1760, 2240-2440, 2900-3010)
  - `bend2/comp.ts` (l.300-320, 3238-3250, 3520-3620, 4593-4700, 4790-5300, 5442)
  - `bend2/main.ts` (l.30-200, 410-460)
  - `demos/app_triangle_2d/main.bend`
  - `demos/app_slash_boss_3d/{README.md, main.bend parts, bend3d.bend parts}`
  - `bench/runtime/mandelbrot/main.bend`
- Prior art: `subtleGradient/bend-ui` `gpui-bend-research.md` (headings only). It already proposes Bend as a pure core with a JS or Rust/GPUI renderer host, which is the P4 shape.

### Boundaries
- **Into the screen:** only `Window.frame(Window, Image)`.
  - The Image is a quadtree of 24-bit RGB `Pix`. Alpha is forced to 1, so there are no transparent windows and no window blur-behind.
  - The window has a fixed size and is not resizable.
  - The window is sized in points and the drawable in pixels, both set to `(w,h)`, and nothing in window.c reads `backingScaleFactor`. So a frame is 1 Image pixel per point, and on Retina it is upscaled. This is read from code, not checked visually.
  - The call is vsync-locked through `nextDrawable` and serialized by `waitUntilCompleted`, so frames cannot be pipelined.
- **Input:**
  - Key events carry the lowercase first character, or `65536+keyCode`. Modifiers arrive as Key events.
  - There is no IME/text input, clipboard, cursor shape, resize, scale, focus events or menus.
  - Events arrive only once per frame.
- **Adding things:**
  - Effects are `.c`/`.js` foreign defs spliced into the single C file and run only by the event loop.
  - A handle type must be a Base law (WONTFIX #825), so a custom renderer must reuse `Window`.
  - The C side uses runtime internals (`term_aux`, `ctr_take`, `f32_unbox`, `e.mem`, `H_BUMP`) with "no ABI promise".
  - There is no native-library target: Bend cannot be called from Rust (WONTFIX #813, "planned, not scheduled").
- **Arrays:** `Array<T>` is one flat block, but it has one owner and "cannot go down a fork tree" (SHADERS.md). Sharing it across lanes needs `@unsafe Array.fork`.
- **Path by path:**
  - **P1** (CPU raster, then Window present): works today with Base only. Measured below.
  - **P2** (`!` compute raster): works, but frame time is set by a fixed bang cost of about 0.25-0.6 ms and by tree balance. Two bangs per frame (render and drop) are the norm. Scene binning must happen on the host or the GPU loses to the CPU. A flat framebuffer needs `@unsafe` plus a custom present effect.
  - **P3** (Bend drives Metal or wgpu through foreigns, shaders in MSL/WGSL): has a direct precedent in Bend's own `window.c`, which compiles an MSL string at runtime with `newLibraryWithSource` and dispatches it. The scene would be marshalled by walking Bend lists in C, as `audio_write_run` does.
  - **P4** (Bend computes scene/layout, native renderer draws): Bend must be the host binary. Either emit `-o x.c` and link a Rust staticlib by hand (the CLI cannot add libraries), or use a process boundary (TCP/UDP/`Process.run` effects exist).

### Experiments Run
All runs used `BEND_NO_TELEMETRY=1`, from `scratchpad/d/exp`, building with `bun ../bend/bend2/main.ts X.bend -o X` and running `./X`, `./X --gpu off`, `./X --gpu off --threads 1`.
- Values are medians of 30-60 frames, first frame excluded. The first bang in a process costs 75-360 ms.
- The machine had load average about 5.4 from other processes (other bun jobs, WindowServer), so expect noise.
- Every GPU, CPU-12 and CPU-1 run produced identical checksums.

1. **`sdf.bend`**: 2,080,768 px, each with 4 rounded-rect SDFs plus blending, reduced to a U32. 2^14 leaves of 127 px.

   | Executor | Median | Notes |
   |---|---|---|
   | GPU (Metal) | 0.665 ms | min 0.565 |
   | CPU, 12 threads | 5.06 ms | |
   | CPU, 6 threads | 5.76 ms | |
   | CPU, 1 thread | 25.6 ms | |
   | C `-O3`, 1 thread (`native.m`, same math) | 20.2 ms | checksum 119989906 matches Bend |
   | Native Metal kernel (`MathModeSafe`, contract off, `precise::sqrt`) | 0.351 ms wall | 0.184 ms GPU-side, checksum matches |
   | Empty Metal command buffer, commit and wait | 0.022 ms | |

   Over 200 frames (`sdf200`) the GPU held about 0.6 ms with roughly 2 ms spikes about every 11 frames.

2. **Bang overhead** (`ovh.bend`, plus a build with `gpu_pass` instrumented to read `GPUEndTime - GPUStartTime`, `ovhp.c`):

   | Bang | GPU-side median | Wall median |
   |---|---|---|
   | single task | 244 µs (min 140) | 405 µs |
   | 1024 trivial leaves | 383 µs | 537 µs |
   | 16384 trivial leaves | 436 µs | 603 µs |
   | 65536 trivial leaves | 364 µs | 529 µs |

   - Every bang took exactly 1 pass.
   - 30,000 single-task bangs (`ovh1`) took 7.92 s, or 264 µs each.
   - `sample` profile: 1637 of 1683 samples were in `-[_MTLCommandBuffer waitUntilCompleted]`. The cost is the device scheduler kernel, not host code or Metal's own latency.
   - CPU pool: a single task costs about 0. 16384 leaves cost 51 µs (12 threads) or 62 µs (1 thread); 65536 leaves cost 67 µs or 209 µs.

3. **`image.bend`**: the same frame built as an `Image`.
   - The per-pixel tree has 527,731 leaves. The flat-collapsed tree has 51,538 leaves. Their on-screen checksums are identical (2383545200) on GPU and CPU.

   | Executor | Per-pixel render | Per-pixel drop | Flat render | Flat drop |
   |---|---|---|---|---|
   | GPU | bimodal: 0.9-1.4 ms or 8.5-10.5 ms | 0.65-0.9 ms or 2.5-4.3 ms | 3.0-4.1 ms (imbalanced tree) | 1.3-1.9 ms |
   | CPU, 12 threads | 4.3 ms | 0.40 ms | 0.47 ms | 0.09 ms |
   | CPU, 1 thread | 27 ms | 1.9 ms | 2.3 ms | 0.17 ms |

   The instrumented build (`image200p.c`) showed:
   - Each render and each drop is 1 pass.
   - The GPU-side time itself is bimodal: about 0.78 ms or about 8.2 ms.
   - The heap bump stayed at 38379 pages across both fast and slow frames, so fresh page faults are not the cause.
   - Moving the drop to the CPU (`image200c`) did not remove the bimodality.

4. **Present kernel** (`blit.c`: the `window_dev` MSL copied verbatim, run headless into an offscreen 1920x1080 BGRA8 texture).
   - GPU-side: 202 µs for the per-pixel tree, 115 µs for the flat tree. Wall time 0.3-0.4 ms.
   - In `--gpu off` mode the same kernel cost 0.8-2.9 ms wall, because it reads freshly CPU-written heap pages.
   - Full frame (render, present kernel, drop):

   | Mode | Per-pixel tree | Flat tree |
   |---|---|---|
   | GPU | 9.7 ms median (min 2.0) | 4.8 ms |
   | CPU, 12 threads | 8.1 ms | 0.97 ms |

   - I did not open a real window. `Window.open` activates the app and takes focus on the desktop.

5. **GPUI-like scene**: a rounded panel plus N rounded cards, output as `Image`, with frame totals including the present kernel and drop. All three executors produced identical checksums.

   | Scene | N=256 | N=1024 | N=4096 |
   |---|---|---|---|
   | (a) culling inside the bang, GPU | 5.8 ms | 26.4 ms | 33.7 ms |
   | (a) culling inside the bang, CPU 12 threads | 5.2 ms | 8.3 ms | 8.8 ms |
   | (a) culling inside the bang, CPU 1 thread | 26.6 ms | 32.1 ms | 41.8 ms |
   | (b) host-binned to 64-px cells (SHADERS.md design), GPU | 4.4 ms (render 2.6) | 5.1 ms (render 2.2) | 7.4 ms (render 2.75, bin 0.8) |
   | (b) host-binned, CPU 12 threads | 5.5 ms | 8.3 ms | 8.8 ms |

   - (a) is `scene.bend`: the top levels of culling run serially, on a few slow GPU lanes.
   - (b) is `scene2.bend`.
   - Leaf counts are 643K to 969K, so the tree is about 10 MB of nodes per frame.

6. **Shared texture** (`atlas.bend`): 2.08M random reads from a 64K-word `Array<U32>` passed down 2^14 leaves with `@unsafe Array.fork`. GPU 0.93 ms, CPU 12 threads 3.24 ms, CPU 1 thread 1.77 ms. 12 threads were slower than 1; I did not find out why. Checksums identical (934563547).

7. **Flat framebuffer** (`fb.bend`, `fb2.bend`): an `Array<U32>` of 2^21 cells filled in parallel with `Array.fork`, then read back on the host.
   - GPU 0.87 ms, CPU 12 threads 2.6 ms, CPU 1 thread 8.6 ms. A sequential fill took 8.5 ms.
   - The host checksum was 119989906, equal to C.
   - The same fill in C `-O3` (`cfill.c`) took 18 ms. Bend was 2x faster here but 1.25x slower than C on the fused hash loop. I did not explain the difference.

8. **Compile times**

   | Program | Emit C | clang `-O3` | `--gpu-build` | Total |
   |---|---|---|---|---|
   | first hello build | | | | 3.1 s |
   | `image.bend` | 0.11 s | 0.40 s | 0.55 s | about 1.1 s |
   | slash boss | 1.52 s (3.34 MB of C) | 8.36 s | 2.64 s / 1.83 s (1.0 MB archive) | about 12.5 s |

   - Slash boss check alone: 0.22 s. JS emit: 0.09 s.
   - There are no incremental builds.
   - I did not run the slash-boss probe, because it opens the audio device with `Audio.open(48000)`.

### Non-Obvious Things
- **The cost is the bang, not the compute.** Bend's device code runs near native speed: about 0.17 ms of actual work against 0.18 ms GPU-side for hand-written Metal. But each `!` has a GPU-side floor of about 0.25-0.45 ms, set by the persistent scheduler's grow and work dispatches. Native Metal round-trips in 22 µs.
- **Base already spends two bangs per frame**, render plus `Image.drop!` in `App.turn`. SHADERS.md avoids the second one by sinking the old image inside the next frame's fork tree.
- **The GPU wins only on balanced 4^7-leaf trees with the scene binned on the host.** The things a UI quadtree wants work against it on the GPU: flat-region collapse and early-out trees are imbalanced, and culling at the top levels is serial. The CPU pool (fixed cost about 50-70 µs) wins for flat UI frames, about 1 ms against 4.8 ms.
- **The present path is itself a GPU kernel** that walks the tree per pixel (about 0.1-0.2 ms). The Image format, not a framebuffer, is the interface, and a per-pixel-dense tree is 5-10 MB of heap writes per frame.
- **Text is the hardest part.**
  - A shared read-only random-access buffer (a glyph atlas) is only possible through `@unsafe Array.fork`, which is outside the proof guarantees and marked experimental.
  - There is no font rasterizer, shaper or CoreText access in Bend (strings are linked lists).
  - Retina text would also need the scale handling that window.c does not have.
- **There is no transparency or offscreen intermediate.** Backdrop blur, MSAA paths and video surfaces have no equivalent in a 24-bit quadtree. Blur needs random-access reads of the layer below.
- **`!` only offloads at the root of an IO step.** Inside CPU-parallel work it silently runs on the CPU. A bang following host forks in the same evaluation also runs on the CPU, so the scene build and the bang must be separated by an IO step.
- **Shell gotcha.** In zsh, `./X $mode` passes `"--gpu off"` as one argument, which silently leaves the GPU on. I corrected for this; every number above used literal flags.

### Open Questions
- What causes the bimodal 0.8 ms versus 8.2 ms GPU-side time in tree-building bangs (one pass each, and not page faults)? Display-synchronous GPU time-slicing, power state, or allocator locality? It does not occur in the scalar-output kernel. It needs Metal System Trace on an idle machine.
- What does the real `Window.frame` cost end to end, including `nextDrawable`/vsync and event pumping, at 120 Hz? I measured the identical kernel headless only.
- Why is Bend's flat fill 2x faster than my C, while its fused hash loop is 1.25x slower? This is a codegen detail I did not trace.
- Can a custom present effect read an `Array<U32>` block zero-copy from `gpu_buf`? That would avoid the quadtree entirely. It is possible in principle given how window.c uses `gpu_buf` and heap offsets, but I did not build it.
- Does SHADERS.md's 8 ms per frame for slash boss on an M4 reproduce on this M3 Pro? I did not run it because of the audio device.

Measured files are in `research/d/exp/`: `sdf.bend`, `ovh.bend`, `ovhp.c`, `image.bend`, `image200p.c`, `present.bend`, `blit.c`, `scene.bend`, `scene2.bend`, `atlas.bend`, `fb.bend`, `fb2.bend`, `native.m`, `cfill.c`, `clock.c`, and the `*.txt` output logs. Slash-boss build artifacts are in `scratchpad/d/slash/`.