### Components Found

**Workspace map** (`git clone --depth 1` of zeronsh/zui at HEAD 667d0aa). Line counts come from `find … -name '*.rs' | xargs cat | wc -l` because tokei, cloc and scc are not installed. Total: 152,848 lines of Rust plus 4,530 lines of shaders.

| Crate | Rust LOC | Shader LOC | Class | What it is |
|---|---|---|---|---|
| gpui | 75,141 (src 64,961, examples 10,102, tests 55; about 5,430 of src is the test/bench harness) | 0 | framework logic (portable in principle) | App, entities, windows, elements, layout, text layout, scene, dispatch, executor front-end, platform traits |
| gpui_macos | 14,045 | 1,377 (`shaders.metal`) | platform glue | Cocoa windowing, Metal renderer, CoreText, CVDisplayLink, GCD, pasteboard, keyboard, accessibility |
| gpui_linux | 14,883 | 0 | platform glue | Wayland and X11 clients, xkb, XIM, clipboard, calloop dispatcher; text and rendering come from gpui_wgpu |
| gpui_windows | 13,655 | 1,504 (HLSL) | platform glue | Win32, DirectX 11, DirectWrite. Bend does not support Windows hosts (WONTFIX #788) |
| gpui_wgpu | 5,792 | 1,649 (WGSL) | platform glue (renderer and text) | wgpu renderer plus `cosmic_text_system.rs` (cosmic-text/swash), used by Linux and web. **There is no blade backend in zui**: `grep -ril blade` finds nothing |
| gpui_web | 3,010 | 0 | platform glue | wasm, canvas, WebGPU through gpui_wgpu, and a single-threaded mode |
| gpui_platform | 186 | 0 | glue selector | `current_platform()` cfg switch (`gpui_platform.rs:36-60`) |
| gpui_macros | 3,470 | 0 | utility (proc macros) | `derive(Action, IntoElement, Render, AppContext, VisualContext)`, `style_helpers!` plus 8 other style-method macros (`styles.rs`, 1,417 lines), `#[gpui::test]` |
| refineable + derive_refineable | 680 (548 of it is the derive) | 0 | utility (macro) | Generates `StyleRefinement`-style Option-per-field structs |
| scheduler | 2,760 | 0 | framework logic | Executors and the test scheduler |
| sum_tree | 3,318 | 0 | utility | B-tree; gpui uses it only in `tab_stop.rs` |
| collections | 418 | 0 | utility | Fx hash maps, re-exports |
| gpui_shared_string | 203 | 0 | utility | `SharedString(SmolStr)` |
| gpui_util | 721 | 0 | utility | |
| gpui_tokio | 100 | 0 | utility/glue | Tokio bridge |
| http_client / http_client_tls / reqwest_client | 1,309 / 21 / 416 | 0 | utility (reqwest_client is a dev-dependency only) | |
| util / util_macros / path | 9,617 / 286 / 1,372 | 0 | utility (reached through http_client's optional `util`; `path` is GPL-3.0) | |
| media | 406 | 0 | platform glue (macOS CoreMedia) | |
| tooling/perf | 1,039 | 0 | tooling | |

**Subsystems inside `gpui/src`.** These counts include inline `#[cfg(test)]` modules; there are 267 test attributes.

| Subsystem | LOC |
|---|---|
| App/entity model (`app.rs`, `app/{entity_map,context,async_context}`) | 5,655 |
| `window.rs` (frame, dispatch, paint API) | 7,125 |
| `window/` (a11y, prompts) | 1,450 |
| `elements/` | 12,930 (`div.rs` 4,911, `list.rs` 2,965, `text.rs` 1,313, `img.rs` 888, `uniform_list.rs` 865, `anchored` 398, `animation` 386, `svg` 276, `canvas` 95) |
| `element.rs` + `view.rs` | 1,299 |
| Text system | 5,127 (`line_wrapper` 1,623, `line_layout` 1,108, `line` 1,015) |
| `scene.rs` + `bounds_tree.rs` + `path_builder.rs` | 2,098 |
| Geometry and color | 5,200 |
| `style.rs` + `styled.rs` + `taffy.rs` | 3,191 |
| Input/actions/keymap/focus/tab stops | 5,393 |
| Platform traits and keystroke/keyboard/menus | 4,671 |
| Executor | 1,360 |
| Assets/SVG | 698 |
| Miscellaneous (subscription, arena, inspector, profiler, docs) | 3,050 |
| Test harness | 5,703 |

**External crates a Bend version would also have to replace.** Lines in `src/` from the local `~/.cargo/registry`:
- Layout: taffy 0.12.2, 22,150 (flexbox, grid, block, float).
- Text: cosmic-text 0.19, 11,805 (uses harfrust 0.5 for shaping and skrifa 0.40); swash 0.2.6, 26,513; harfrust, about 32,500; skrifa, about 34,000; read-fonts, about 35,000; ttf-parser, 23,196.
- Atlas: etagere, 2,666.
- Paths: lyon_tessellation, 33,647; lyon_geom + lyon_path, about 16,000.
- SVG: resvg + usvg 0.46, 23,127; tiny-skia, 14,640.
- slotmap, 8,802.

The resolved closure for `gpui_platform` on aarch64-apple-darwin is **301 crates** (329 with build dependencies).

**The layers**
- **Platform boundary** (`gpui/src/platform.rs`): `Platform` (line 125), `PlatformWindow` (794; `on_request_frame` 827, `on_input` 836, `draw` 846), `PlatformDispatcher` (1013), `PlatformTextSystem` (1043), `PlatformAtlas` (1295), `InputHandler` (1625).
- **macOS** (`gpui_macos`):
  - `platform.rs:494-521` runs `NSApplication run`.
  - `window.rs:156` builds a `GPUIView` NSView subclass at runtime with `ClassDecl` and about 45 `add_method` calls, plus GPUIWindow, GPUIOverlayView and BlurredView.
  - `handle_view_event` (2605-2748) turns an NSEvent into `PlatformInput` and calls the stored `event_callback`.
  - `display_link.rs` keeps one immortal CVDisplayLink per display. It feeds a DATA_ADD dispatch source on the main queue, which calls `step` (window.rs:3032) and then `request_frame_callback`.
  - `dispatcher.rs:31-79` maps foreground and background runnables onto the GCD main and global queues.
  - `text_system.rs` uses font-kit and CoreText (`layout_line` 532-628 goes through `CTLine` with UTF-8↔UTF-16 conversion; rasterization uses a `CGBitmapContext`). Without the `font-kit` feature it falls back to `NoopTextSystem` (`platform.rs:206-213`).
- **Renderer** (`metal_renderer.rs`):
  - `new_internal` (290-453) builds 9 pipeline states: path rasterization, path sprites, shadows, backdrop blur (no blending), quads, underlines, monochrome sprites, polychrome sprites, surfaces.
  - `draw_frame` (573-648) gets the next drawable, then `draw_primitives_to_texture` (950-1216) loops over `scene.batches()` and encodes instanced draws over unit-quad vertices. It breaks the render pass for each backdrop blur (blit, then an MPS Gaussian through `msg_send!`, then repaint) and does paths in two passes (MSAA intermediate, then sprite). It ends with `present_drawable` and `commit`.
  - Shader struct layouts are generated from the Rust structs by `build.rs` (cbindgen produces `scene.h`, then `xcrun metal` and `metallib`).
  - The `runtime_shaders` feature instead compiles the MSL at runtime with `new_library_with_source`.
  - The Gaussian blur comes from Apple's Metal Performance Shaders (MPS).
  - The glyph atlas is `metal_atlas.rs`, built on etagere `BucketedAtlasAllocator` and `replace_region`.
- **Scene** (`scene.rs`):
  - `Scene` (41-57) holds separate Vecs per primitive kind (shadows, quads, paths, underlines, mono/subpixel/poly sprites, surfaces, backdrop_blurs) plus a `paint_operations` log.
  - `insert_primitive` (114-166) assigns a draw order from `BoundsTree`, an R-tree that gives non-overlapping primitives the same order so they batch.
  - `replay` (168) and `finish` (179, sort by order) complete the picture.
  - All primitives are `#[repr(C)]` plain data made of f32/u32: `Quad` 613, `Shadow` 669, `BackdropBlur` 658, `MonochromeSprite` 806, `PolychromeSprite` 846, `AtlasTile` (platform.rs:1343).
  - The quad fragment shader does rounded-rect SDFs, dashed borders and gradients; shadows use an erf blur.
- **Text**:
  - `TextSystem` (text_system.rs:51) keeps caches behind RwLock/Mutex.
  - `WindowTextSystem::shape_line/shape_text/layout_line` go through `LineLayoutCache`, which has previous and current frame caches and `reuse_layouts`.
  - Glyphs are drawn by `Window::paint_glyph` (window.rs:4311): quantize to subpixel variants, call `sprite_atlas.get_or_insert_with` (rasterizing on a miss), and emit a `MonochromeSprite` or `SubpixelSprite`.
- **Layout** (`taffy.rs`):
  - `TaffyLayoutEngine` wraps `TaffyTree<NodeContext>` and is cleared every frame (window.rs:2820).
  - `request_layout` (65) and `request_measured_layout` (88) store a boxed `FnMut` measure closure (`NodeMeasureFn` 20-29) that text uses.
  - `compute_layout` (192) does pixel snapping.
- **Entity/View/Element model**:
  - `App` (app.rs:679-765) owns everything: `entities: EntityMap`, `windows: SlotMap<WindowId, Option<Box<Window>>>`, about 13 `SubscriberSet`s of boxed callbacks, `pending_effects: VecDeque<Effect>`, globals keyed by `TypeId`.
  - `EntityMap` (entity_map.rs:56) is `SecondaryMap<EntityId, Box<dyn Any>>` plus `Arc<RwLock<SlotMap<EntityId, AtomicUsize>>>` ref counts. Handles (`AnyEntity`, `Entity<T>` 414) increment in Clone (311) and decrement in Drop (339), pushing to `dropped_entity_ids`.
  - `update_entity` (app.rs:2647) uses a lease: `EntityMap::lease` removes the state from the map, the closure runs, `end_lease` puts it back. A double lease panics.
  - `Context<T>` (context.rs:20) is `&mut App` plus `WeakEntity<T>`; it provides `notify` (229), `observe` (63), `listener` (252-260, captures a `WeakEntity`) and `spawn` (237).
  - `Render::render(&mut self, &mut Window, &mut Context<Self>) -> impl IntoElement` (element.rs:163) and `RenderOnce` (179).
  - The `Element` trait (51-142) has associated `RequestLayoutState` and `PrepaintState` and three phases. `Drawable<E>` (254-286) is a phase state machine driven by `mem::take`. `AnyElement` is an `ArenaBox<dyn ElementObject>` allocated in a per-frame bump arena (`arena.rs`).
  - `view.rs`: `AnyView` is `{AnyEntity, render: fn pointer}` (19-22); there is a `View` trait (182) and `ViewElement` with optional caching (`Entity::cached(style)`; prepaint at 362-446 reuses the previous frame's ranges when the view is not dirty).
- **Executor**: `BackgroundExecutor` and `ForegroundExecutor` (executor.rs:14,22) wrap the `scheduler` crate. Futures become async-task `Runnable`s handed to `PlatformDispatcher`. Callers: tooltip delay, the 1-second pending-keystroke timeout (window.rs:5358), asset loading (`use_asset` 3588), accessibility channels, macOS synthetic drag.
- **Input, actions and keymap**:
  - `Window::dispatch_event` (5070).
  - Mouse dispatch (5202-5258) is a **flat list** of every `mouse_listeners` entry registered during paint: a capture pass in registration order, then a bubble pass in reverse. Each listener filters itself with `hitbox.is_hovered`.
  - Key dispatch (5260-5426) is tree-based: `DispatchTree` (key_dispatch.rs:71) nodes carry `key_listeners: Vec<Rc<dyn Fn>>`, action listeners keyed by `TypeId`, context and focus id. The flow is focus path, then keymap match with pending multi-stroke state, then actions, capture and bubble (5585; bubble stops by default), with global listeners on either side.
  - `Action` is a trait (action.rs:117) registered with `inventory`.
- **Focus**: `FocusHandle` (window.rs:397) is ref-counted in `Arc<RwLock<SlotMap<FocusId, FocusRef>>>` with Drop at 523. Releases are swept in `flush_effects`. `tab_index` is `isize`.
- **Hitboxes**: `insert_hitbox` (4792) appends to `next_frame.hitboxes`. `Frame::hit_test` (1013-1035) walks them in reverse, honoring `BlockMouse` and `BlockMouseExceptScroll`.
- **Element state**: `with_element_state<S>` (3817-3890) takes the state from `next_frame.element_states`, or failing that `rendered_frame.element_states`, keyed by `(GlobalElementId, TypeId)`, passes it to the closure, and stores the returned state.

**Rust features GPUI depends on, and what each would become in Bend 2.** Counts are for `gpui/src` without test files (74 files, 59,531 lines).

| Feature | Where | Bend mapping |
|---|---|---|
| Ref-counted shared entity handles (`Rc` 127, `Arc` 165, Weak/downgrade 74, `.clone()` 731) and the entity map | `entity_map.rs`, `FocusHandle`, `AnyView` | Handles become plain U32 ids (numbers can be reused). The store becomes an id-keyed tree holding one closed sum type of all entity states, since there is no `Box<dyn Any>`. The lease pattern (take, update, reinsert) maps directly. There is no Drop, so ref-count release needs explicit `release(id)` or a per-frame sweep reachable from window roots. Base `Map` is String-keyed (`base.bend:86-89`), so a U32-keyed map has to be written. |
| Boxed closures stored as listeners that capture handles (`impl Fn*(` 299, `dyn Fn*(` 115, `move \|` 275) | `Frame.mouse_listeners: Vec<Option<Box<dyn FnMut>>>`, `DispatchNode.key_listeners: Vec<Rc<dyn Fn>>` cloned on each dispatch, `cx.listener`, and div click wiring (div.rs:2732-2913, where several closures share `Rc<RefCell<Option<MouseDownEvent>>>` and an `Rc` click-listener Vec) | **The main blocker.** Listeners live across a whole frame and run on many events, and some are shared. Affine closures cannot do that. Defunctionalize: listeners become data (message constructors) stored next to hitbox and dispatch-node ids, interpreted by one `update(state, msg)` function. The shared `RefCell` state moves into the keyed element-state map. |
| Trait objects (`Box<dyn` 146, `Rc/Arc<dyn` 83, `dyn Any` 56, `TypeId` 94, downcast 65) | `AnyElement`, the five platform traits, `dyn Action`, events and globals stored as `dyn Any` | No traits in Bend, so these become closed sum types (`Element = Div \| Text \| Img \| Svg \| List \| …`) and custom elements lose open extensibility. Platform traits become effect defs. Action and event `TypeId` matching becomes constructor tags. Per-frame element objects are each called once per phase, which works with affine closures if render rebuilds them every frame. |
| Generics (`impl<` 204, 58 trait definitions) | `Point/Size/Bounds/Edges/Corners<T>` over Pixels/ScaledPixels(f32)/DevicePixels(**i32**), `Entity<T>`, `Context<T>`, `EventEmitter<E>`, `with_element_state<S>` | Bend has parametric and dependent types (`App<S>`, `Map<a,V>`), but trait-bounded generics (`T: Add`, `Into<Background>`, `IntoElement`) need explicit dictionaries or one copy per type. |
| derive/proc macros (`#[derive(` 342) | `Refineable` (Style, TextStyle, Bounds, Edges, Corners), about 114 hand-written plus macro-generated Tailwind methods (`styled.rs:26-34`), `derive(Action)` with `inventory` link-time registry, `#[gpui::test]` | No macros in Bend: write them by hand or generate Bend source with an external script. |
| async/await (37 async, 31 `.await`; macOS 21/3; Linux+wgpu 24/52) | executor, timers, asset loading, a11y, pending keystrokes | No async/await. Bend has IO do-notation, spawn/channels/sleep effects, and one event loop. Model these as commands returned from update, with results arriving as messages, and timers as time checks each frame. |
| unsafe FFI (gpui_macos: 383 `unsafe`, 324 `msg_send!`, 188 `extern "C"`) | ObjC classes, Metal, CoreText, CVDisplayLink, GCD, NSTextInputClient | Only possible through effect `.c` files spliced into the generated C (`guide/EFFECTS.md`). There is no ABI promise, and a new handle type is WONTFIX #825, so reuse the `Window` handle or pass U32 ids. |
| Interior mutability (`RefCell/Cell` 83, `Mutex/RwLock` 20, atomics) | `WindowInvalidator: Rc<RefCell>`, `needs_present: Rc<Cell>`, text caches, atlas, `ScrollHandle` | Thread state explicitly through calls. Bend's `Window.frame` already returns `Window & Image & List<Event>`. |
| Numbers: f32 342, f64 35, signed ints 48, u64/usize 526, u8/u16 84 | DevicePixels i32, `tab_index` isize, 64-bit hashes (Fx, seahash), EntityId u64 | Bend has Nat (48-bit immediates), U32 and F32 only; U64 and F64 are listed as "SOON". Signed values need two's complement on U32: the triangle demo tests sign with `> 2147483647 : U32`. Hashing must be redone in 32 bits. |
| Strings (`String`/`SharedString` 337) | text runs with UTF-8 byte indices, CoreText UTF-16 | Bend strings are cons lists of `Chr{U32}`, so byte-indexed ranges and shaping input need a different representation. |

**What zui's "standalone, not a fork" model is**
- GitHub reports `fork: false`, `parent: null`; the repo was created 2026-08-25 and has 47 commits.
- The root commit `0b18592` has **no parents** and adds 172,559 lines. Its message reads "Extract GPUI fork from wingleeio/zed into a standalone workspace", sourced from `wingleeio/zed@e2ddcc68`. That repo is a GitHub fork of zed-industries/zed, and the pin is upstream `f14fea9` plus Zeron's "comet" patch line.
- It contains gpui, gpui_platform and gpui_tokio plus their in-tree dependency closure: 27 crates at extraction, 24 workspace members now after removing ztracing, ztracing_macro and zlog.
- The root manifest is pruned to the workspace dependencies actually used. Cargo.lock is Zed's, "pruned by resolution". Unused `[patch.crates-io]` entries were dropped.
- Crate paths keep Zed's layout (`crates/<name>`, `tooling/perf`), so upstream patches apply with the same `-p` level: `git -C ../zed format-patch -1 <sha> --stdout | git apply --3way`.
- Licensing: Apache-2.0 for most crates, and `LICENSE-GPL` because `path` is GPL-3.0-or-later. `NOTICE` credits code adapted from egoist/zed.
- `crates/gpui/Cargo.toml` still says `repository = "https://github.com/zed-industries/zed"`, author Nathan Sobo, version 0.2.2.
- For a Bend version, only the provenance discipline carries over: a pinned source commit, a README provenance section, matching module names, and keeping the Apache license and NOTICE for derived work. Patch porting would be manual semantic translation, because `git apply` cannot cross languages.

### Flow

One frame, end to end: a click on a div with `on_click(cx.listener(|this, _, _, cx| { this.n += 1; cx.notify(); }))`.

1. **OS event.** AppKit calls a `GPUIView` method, which goes to `handle_view_event` (gpui_macos `window.rs:2605`). It converts the event with `platform_input_from_native`, rewrites ctrl-click into a right click, takes `event_callback`, drops the lock, calls it, and puts it back (2742-2746).
2. **Into GPUI.** The callback was installed by `Window::new` through `platform_window.on_input` (gpui `window.rs:1706-1714`). It calls `handle.update(&mut AsyncApp, |_, window, cx| window.dispatch_event(event, cx))`. That goes through `App::update_window_id` (`app.rs:1772`), which takes the `Box<Window>` out of `App.windows` (another lease) and wraps the call in `App::update` (`start_update`/`finish_update`, 1029-1047).
3. **Dispatch.** `dispatch_event` (5070) records modality and mouse position, then `dispatch_mouse_event` (5202). That recomputes `rendered_frame.hit_test` against `rendered_frame.hitboxes`, does `mem::take` of `rendered_frame.mouse_listeners`, and runs the capture and bubble passes. The div's MouseDown closure (`div.rs:2756`) stores `pending_mouse_down` in an `Rc<RefCell>`. On MouseUp (2866), the capture phase moves it to `captured_mouse_down` and the bubble phase calls each `click_listener`.
4. **State update.** `cx.listener` runs `WeakEntity::update`, which calls `App::update_entity` (2647): `EntityMap::lease`, run the user closure with `Context<T>`, then `end_lease`.
5. **Notify.** `Context::notify` (context.rs:229) calls `App::notify(entity_id)` (`app.rs:2522-2556`). If the entity is tracked by a window, `WindowInvalidator::invalidate_view` (window.rs:155) inserts into `dirty_views`, sets `dirty = true`, calls `frame_requester()` and pushes `Effect::Notify`. Otherwise only `Effect::Notify` is queued. When the outermost update ends, `flush_effects` (1581-1637) loops over `release_dropped_entities`, `release_dropped_focus_handles` and each effect; Notify calls the observers (`apply_notify_effect` 1684). Back in `dispatch_event`, a higher `update_count` triggers `request_frame` (5185-5188).
6. **Frame tick.** The CVDisplayLink fires the dispatch source on the main queue, which calls `step` (gpui_macos 3032) and then the `on_request_frame` closure from `Window::new` (gpui 1543-1641). That closure throttles for thermal state and inactivity and runs `next_frame_callbacks`. If `invalidator.is_dirty()`, it calls `window.draw(cx)` then `window.present()`, then `complete_frame`, and possibly `pause_frame_requests`.
7. **Draw** (2766-2889): `invalidate_entities` runs `mark_view_dirty` on the dirty views and their ancestors (1900), then `draw_roots` (2963-3085).
8. **render() builds the tree.** `root.into_any_element()` creates `ViewElement`. Its `request_layout` (view.rs:314) calls `View::render`, which is `Entity::update` then `Render::render`, returning a `Div`. `AnyElement::new` allocates it in the frame arena.
9. **Layout.** Each element's `request_layout` calls `window.request_layout(style, child_ids)` (4706), which becomes taffy `new_with_children`. Text uses `request_measured_layout` with a boxed closure. Then `stretch_auto_size_to_fill`, then `prepaint_as_root`, which runs `layout_as_root`, then `compute_layout` (4755), which is taffy `compute_layout_with_measure` calling the measure closures and snapping to pixels.
10. **Prepaint.** `Drawable::prepaint` (element.rs:344) gets `layout_bounds`, pushes a `dispatch_tree` node, then calls `Element::prepaint`. Prepaint inserts hitboxes, sets focus ids and tooltips, and may use `transact` for autoscroll. Cached views call `reuse_prepaint` (3283), which copies hitboxes, moves tooltips, reuses the dispatch subtree and replays line layouts. Then `prepaint_deferred_draws`, prompt, drag or tooltip, and `mouse_hit_test = next_frame.hit_test(...)`.
11. **Paint.** `Element::paint` calls `paint_quad` (4127), `paint_glyph` (4311, filling the atlas on a miss), `paint_backdrop_blur` (4086), and so on, which call `next_frame.scene.insert_primitive`. Paint also registers listeners for the next frame with `on_mouse_event` (4909), `on_key_event` (4932) and `handle_input` (4888). Cached views call `reuse_paint` (3347), which moves listeners and replays scene operations. Deferred draws are painted on the overlay plane.
12. **Finish.** `next_frame.finish` sorts the scene by order, `rendered_frame` and `next_frame` are swapped, focus-change listeners run, `record_entities_accessed` updates which entities this window tracks, and `needs_present` is set.
13. **Present** (2930): presentation callbacks run, then `platform_window.draw_layered(scene, overlay_start, capture)`, which reaches `MetalRenderer::draw` (566) and `draw_frame` (573). That gets the next drawable and calls `draw_primitives_to_texture`, which encodes instanced draws for each `PrimitiveBatch` and the blur and path passes, then `present_drawable` and `commit`. A completion block returns the instance buffer to the pool.

**Bend counterpart** (verified in `bend2/base.bend:2940-2986`). `App.run` opens a Window and runs `App.loop`. Each step calls `view(state)` to get `(state, Image)`, then `Window.frame(window, image)`, which returns `Window & Image & List<Event>` (events pulled since the last frame), drops the image, and calls `tick(events, state)`, which returns `IO(Maybe<S>)`. `Window.frame` (`effs/window.c:449-499`) pumps AppKit events inside `window_wait` only while a frame is presenting. A compute kernel walks the `Image` quadtree (`Pix{u32}` / `Qua{4}`) directly in Bend's heap for each pixel and writes it to the drawable texture.

### Files Read

zui (repo-relative):
- `README.md`, `NOTICE`, `Cargo.toml`, `Cargo.lock` (package count), `rust-toolchain.toml`, `.cargo/config.toml`, `.github/workflows/renderer-tests.yml`, `docs/macos-resource-usage.md`
- `crates/gpui/{README.md,Cargo.toml}`, `crates/gpui/src/{_ownership_and_data_flow.rs,app.rs,app/entity_map.rs,app/context.rs,window.rs,element.rs,view.rs,key_dispatch.rs,scene.rs,taffy.rs,platform.rs,executor.rs,bounds_tree.rs (header),arena.rs (header),elements/div.rs (types, Interactivity, click wiring),text_system.rs (outline),text_system/line_layout.rs (outline),interactive.rs (PlatformInput),action.rs (outline),styled.rs (macro calls),geometry.rs/color.rs/style.rs (struct defs)}`, `crates/gpui/examples/hello_world.rs`
- `crates/gpui_platform/src/gpui_platform.rs`
- `crates/gpui_macos/{Cargo.toml,build.rs}`, `crates/gpui_macos/src/{metal_renderer.rs (290-460, 560-650, 950-1290),window.rs (ClassDecl, handle_view_event, display_layer, step),display_link.rs (header),dispatcher.rs,platform.rs (run),text_system.rs (layout_line),metal_atlas.rs (grep),shaders.metal (entry points)}`, `crates/gpui_wgpu/src/shaders.wgsl` (entry points)
- `crates/gpui_web/src/dispatcher.rs` (header), the Cargo.toml of every platform crate, and the lib heads of the utility crates

Bend (for the mapping): `README.md`, `WONTFIX.txt`, `guide/SHADERS.md`, `guide/EFFECTS.md`, `bend2/base.bend` (types 7-121, Window effects 373-390, App loop 2940-2986), `bend2/effs/window.c` (1-520), `window_open.js`, `window_frame.js`, `bend2/main.ts:416-445` (`cli_build`), `demos/app_triangle_2d/{main.bend,LAWS.bend}`

### Boundaries

- **Core to platform.** These are five trait objects created by `gpui_platform::current_platform()`, a cfg switch.
  - Going in: `WindowParams`, `&Scene` (`draw` / `draw_layered`), `PlatformInputHandler`, cursor style, menus.
  - Coming out: boxed callbacks that the platform stores and calls (`on_request_frame`, `on_input -> DispatchEventResult`, `on_resize(Size, f32)`, `on_should_close -> bool`, `on_hit_test_window_control -> Option<..>`, `on_close`, and others), plus `sprite_atlas()`, `scale_factor`, `mouse_position`.
  - **Control is inverted**: the OS owns the loop (`NSApplication run`) and calls into GPUI through closures that capture `AsyncApp` (`Weak<AppCell>`). Bend's model is the reverse: the Bend program owns the loop and pulls events once per frame.
- **Synchronous OS→app queries** that a per-frame event batch cannot answer:
  - `InputHandler` IME methods (`text_for_range`, `bounds_for_range`, `character_index_for_point`, `replace_and_mark_text_in_range`), backing NSTextInputClient.
  - `DispatchEventResult` returned to the OS for key equivalents.
  - `on_should_close -> bool`.
  - Window-control hit testing.
- **Scene to renderer.** The contract is the memory layout of `#[repr(C)]` structs, turned into `scene.h` by cbindgen and compiled into MSL. WGSL and HLSL mirror it by hand. Batching depends on draw order and atlas texture id.
- **Text.** `PlatformTextSystem` returns `LineLayout { runs: [ShapedRun{font_id, glyphs: [ShapedGlyph{id, position, index(utf8)}]}], width, ascent, descent }` and glyph bitmaps as `(Size<DevicePixels>, Vec<u8>)`.
- **Layout.** `Style` goes through `to_taffy` into a `TaffyTree` rebuilt every frame, and comes back as `Bounds<Pixels>` per `LayoutId`.
- **Bend side (verified).**
  - `Window.open(String, U32, U32) -> IO(Result<…, Window>)` and `Window.frame(Window, Image) -> IO(Window & Image & List<Event>)`.
  - `Event = Key{code, down} | Mouse{x, y, button, down} | Move | Look | Scroll{x, y, dx, dy} | Close`. Compare GPUI's `PlatformInput`: KeyDown/KeyUp (with modifiers and `is_held`), ModifiersChanged, MouseDown/Up (with `click_count`), MousePressure, MouseMove, MouseExited, ScrollWheel, Pinch, FileDrop, Touch, plus IME.
  - `Window` is a linear handle (`base.bend:105`) whose value is the retained `NSWindow*` (`window.c:239`). Custom effects may reuse it (WONTFIX #825 says so).
  - The build line is fixed: `clang -x objective-c -fobjc-arc -fmodules -std=c11 -O3 file -lpthread -lm` (`main.ts:433`). There are no extra `-l`/`-L` flags; frameworks link automatically through modules.

### Experiments Run

1. `git clone --depth 1 https://github.com/zeronsh/zui`: 0.87 s. `git clone --depth 1 https://github.com/HigherOrderCO/Bend`: 3.4 s (Bend HEAD 565d7fd, 2026-10-04).
2. Line counts per crate: `for d in crates/*…; find $d -name '*.rs' | xargs cat | wc -l` (results in the table above). `grep -c '^\[\[package\]\]' Cargo.lock` gives 851 across all platforms.
3. Feature-count script at `scratchpad/a/tools/feat.sh` (grep -oE counts). Results are in the mapping table. gpui_macos: 13,806 lines, unsafe 383, `msg_send!` 324, `extern "C"` 188. Linux plus wgpu: 20,190 lines, `Box<dyn` 92, `.await` 52.
4. `cargo tree --offline --locked -p gpui_platform -e normal[,build] --target <t> --prefix none | … | sort -u | wc -l`, about 3.2 s:
   - aarch64-apple-darwin: **301** (normal), **329** (with build deps)
   - x86_64-pc-windows-msvc: 286 / 322
   - Linux and wasm32 returned 0 because crates are missing from the offline cache.
5. `xcrun -sdk macosx metal --version` fails with `cannot execute tool 'metal' due to missing Metal Toolchain; use: xcodebuild -downloadComponent MetalToolchain`. A default `gpui_macos` build (build.rs runs `xcrun metal`) would fail on this machine; `--features gpui_macos/runtime_shaders` avoids that step. No full build was attempted.
6. CoreText under Bend's exact clang flags (`scratchpad/a/exp/ct.c`):
   - Compile: `clang -x objective-c -fobjc-arc -fmodules -std=c11 -O3 ct.c -lpthread -lm -o ct`, 0.145 s with one enum-cast warning.
   - Run `./ct`: `glyph=74 bbox=(0.5,-3.5,7.3,12.1) lit_pixels=83`.
   - So a custom Bend effect can shape and rasterize glyphs with CoreText/CoreGraphics without `-framework` flags.
7. GitHub API: `gh api repos/zeronsh/zui` (fork false, parent null), commit list (47 commits), `commits/0b18592` (no parents, +172,559), `gh api repos/wingleeio/zed` (fork of zed-industries/zed).
8. **Unintended side effect, to disclose:** running `rustup toolchain list` from inside the zui directory triggered rust-toolchain.toml auto-install. It installed `~/.rustup/toolchains/1.95.0-aarch64-apple-darwin` (1.0 GB, 10:53:51), which breaks the "no global installs" rule. I did not remove it because other parallel explorers might be running cargo in a zui clone. To undo: `rustup toolchain uninstall 1.95.0-aarch64-apple-darwin`.

### Non-Obvious Things

- **GPUI already threads much of its state linearly.**
  - `EntityMap::lease`/`end_lease`, `windows: Option<Box<Window>>` take and put back, `with_element_state(FnOnce(Option<S>) -> (R, S))`, `layout_engine.take()`, and macOS `callback.take(); drop(lock); callback(); put back` are all take-then-reinsert.
  - Elements are created each frame and each phase method is called exactly once (`ElementDrawPhase` with `mem::take`).
  - What breaks affinity is mainly event listeners, which outlive render, run many times and are sometimes shared through `Rc`, together with ref-counted handles that rely on `Drop`.
- **Mouse dispatch is not a tree walk.** Every paint-registered mouse listener runs for every mouse event, and each one checks `hitbox.is_hovered` itself. Only key and action dispatch use the `DispatchTree` focus path.
- **GPUI is "hybrid immediate/retained."** The tree is rebuilt every frame, but `Entity::cached(style)` / `ViewElement` replays index ranges of the previous frame (`PrepaintStateIndex`, `PaintIndex`) for hitboxes, listeners (moved with `take()`), scene operations, line layouts and dispatch subtrees. A cached view must have a definite size.
- **Draw orders come from overlap.** `BoundsTree`, an R-tree, assigns them, so non-overlapping primitives share an order and batch together. Primitives are sorted by `(order, tile_id)` in `finish`.
- **Backdrop blur sits outside the batch stream.** The renderer ends the render pass, blits a padded region, runs an MPS Gaussian (cached kernels) and resumes. The Metal, wgpu and DirectX renderers all implement it.
- **Without `font-kit`, macOS uses `NoopTextSystem`.** It lays out text with fake metrics and renders no glyphs, which is a ready-made pattern for a text stub at the start of a port.
- **zui's Linux path is wgpu only.** gpui_linux has a one-line `text_system.rs` that re-exports `gpui_wgpu::CosmicTextSystem`.
- **Bend's GPU path is not a raster pipeline.**
  - `Window.frame` runs one compute kernel that walks a Bend `Image` quadtree per pixel.
  - Bend's documented fast path is a software tile rasterizer in Bend, launched with one `!` bang per frame. The guide describes it as "host walks the world once per frame into per-tile candidates" (`guide/SHADERS.md`; 1920×1200 at 120 FPS on an M4 for a 3D scene).
  - GPUI's `Scene`, a flat list of bounded primitives, fits that model well. GPUI's 1,377-line MSL vertex/fragment design would not be reused as-is; its SDF math (`quad_sdf`, erf shadow blur) would be rewritten as per-pixel Bend code.
- **Bend already ships an Elm-style runtime**: `type App<S> = App{view: S -> (S, Image), tick: List<Event> -> S -> IO(Maybe<S>)}` (`base.bend:120`). GPUI's Entity/Context/notify model would have to be recast as state plus messages on top of it.
- **Gaps in Bend's stock Window** (from `window.c`):
  - Fixed size: the macOS style mask has no Resizable flag, and Linux sets min = max.
  - `drawableSize = w×h`, so no HiDPI.
  - The key code is lowercased `charactersIgnoringModifiers`; modifiers arrive as `65536 + keyCode`.
  - No IME, clipboard, cursor styles, click count, key repeat, resize or focus events, menus or accessibility.
  - AppKit events are pumped only inside `Window.frame`.
  - Because the handle is the `NSWindow*` and custom effects may reuse the Window handle type, extra effects (resize, scale, IME snapshot, cursor) can be written without forking Bend's base.
- **Bend's Base Map is keyed by String** (`MLeaf{key: String…}`). Arrays are affine binary trees (`ALeaf`/`ANode`) that "cannot go down a fork tree", and `Image`, `Event` and ADTs are `Data`, meaning shareable but with a ref-count cost per `SHADERS.md`.
- **Signed values recur in GPUI.** DevicePixels is i32, `tab_index` is isize, and list offsets can be negative (zui commit 2ee37c9 "Fix list scrolling from negative item offsets"). Bend's demo idiom for sign tests is a comparison against 2^31-1 on U32.

### Open Questions

- Whether Bend 2 closures can be applied more than once when not duplicated. Affine suggests at most once. I inferred the defunctionalization requirement but did not verify it in the BendTT paper or the compiler.
- What it costs to share ref-counted `Data` values in Bend (per `SHADERS.md`, about 2× per read) for an entity store and element-state map read every frame. Also how text shaping and line wrapping perform over cons-list strings.
- How big a taffy-equivalent has to be. Full taffy is 22k lines (flex, grid, block, float). What subset GPUI's `Style` actually needs was not measured.
- Whether reusing zui's Metal renderer from Bend (emitting C with `bend x.bend -o x.c`, then a custom clang link against a Rust staticlib) is workable. Not tested.
- Dependency closures for Linux and wasm (the offline cache was incomplete). I did not build or run any gpui example.
- I did not diff zui's `view.rs` (the `View` trait and `Entity::cached(style)`) or the invalidator design (`window_invalidators_by_entity`, `tracked_entities`) against upstream Zed, so whether those are comet patches or upstream is unconfirmed.