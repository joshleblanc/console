# Assignments — learning the Cartridge Console API

Ten assignments plus a capstone, ordered so each one only uses API surface the
previous ones introduced. Every assignment is a real cart you can boot, and
every one has a command that tells you whether it worked.

Work in order. The point is not to ship a game, it is to learn the shape of the
API: what the console already does for you, and what it expects you to decide.

---

## Ground rules

### Commands (all verified in this checkout)

```sh
./bin/run lab01                        # boot your cart
./bin/run lab01 --hud                  # ...with the debug overlay on
./bin/run lab01 --ticks 120            # boot headlessly, quit after 120 frames, exit 0
./bin/run lab01 --shot shots/lab01.png # write a screenshot of the last frames, then quit
./bin/run --list                       # what carts exist
./bin/run-test                         # the console's own suite — must stay green
./bin/smoke                            # boot every cart headlessly, report failures
```

`./bin/run-test` must pass before and after your work. If your cart breaks the
console itself, that is a bug worth reporting, not a reason to skip it.

### A cart is a directory, and its name is its class

```
carts/lab01/app/main.rb       →   class Lab01
carts/dodge-bash/app/main.rb  →   class DodgeBash
```

The directory name is the class name (`Console::Str.camel`), and `app/main.rb`
is the entry point. Every other `.rb` in that `app/` is required automatically,
in sorted order, after the entry file.

Starter skeleton — this is the whole contract:

```ruby
# carts/lab01/app/main.rb
TITLE = 'lab01'          # shown by ./bin/run --list

class Lab01
  def setup;  end       # once, at boot
  def update; end       # every frame (ignored if you define scenes)
  def render; end       # every frame, always last — this is your HUD
end
```

Every method in `Console::API` is available as a bare call inside a cart — no
receiver, no `Console.` prefix. `Console::API` is also included into scene
classes automatically when you register them.

### mruby gotchas that will bite you

The console runs on **mruby 3.0**, which is not CRuby:

| Gotcha | What to do instead |
|---|---|
| No `Regexp` | use `Console::Str` (`chop`, `split_on`, `digits?`, `snake`, `camel`, `fit`) |
| `/` is always float division | `181 / 20` is `9.05`. Grid maths needs an explicit `.to_i` |
| Origin is **bottom-left** | `y:` counts *up*. Prefer `top:` for anything UI-ish |
| One options hash per method | a bare `key: value` list binds to the *first* optional parameter, which is why every widget takes exactly one hash |
| `outputs.solids` is deprecated | fills are emitted as sprites; use `draw.rect` |
| `DR.list_files` is not recursive | the sprite index walks directories itself — don't hand-roll it |
| A scene's hook is `render`, not `draw` | `draw` is the console's rendering object; a scene defining `draw` shadows it |

### Where to read when you are stuck

| File | What it holds |
|---|---|
| `app/console/core.rb` | the whole `Console::API` — the authoritative list of bare calls |
| `carts/hello/app/hello.rb` | the smallest cart that uses most of the surface; read it top to bottom |
| `carts/arcade/app/arcade.rb` | a real game: scenes, waves, camera, tweens, pause |
| `carts/widgets/app/widgets.rb` | every widget, as a live reference |
| `carts/ldtk/app/ldtk.rb` | level loading + a kinematic body |
| `carts/selftest/app/selftest.rb` | the suite — the best usage documentation in the repo |

---

## Tier 1 — Foundations

### 1. Boot probe *(~30 min)*

**Teaches:** the cart contract, `draw.*`, `input.*`, `tick_count`, `top`/`strip`.

Create `carts/lab01/app/main.rb` from the skeleton above, then build a
diagnostic screen — not a game, a probe.

**Spec**

1. `setup` creates one generated texture with `auto_sprite` (pattern `:checker`,
   colour `:accent`).
2. `update` tracks a frame counter using `tick_count` and `seconds`.
3. `render` draws, in one frame:
   - a 56px bar across the top using `draw.within strip(0, 56) do ... end`,
   - a generated sprite inside that bar,
   - a `draw.grid` block in the lower half (`cols: 8, rows: 4`),
   - a label showing `frames_elapsed` and `seconds`, positioned with `top(24)`
     rather than a raw `y:`,
   - two `draw.rect` calls whose `:rect` return values you then pass to
     `draw.border` — proving every draw call composes.
4. `:cancel` quits with `DR.request_quit`. `:debug_toggle` is already wired for
   you; do not reimplement it.
5. `ESC` and the gamepad `:cancel` both work, because you asked for `:cancel`
   and not for "the escape key".

**Verify**

```sh
./bin/run lab01 --ticks 120            # exits 0, nothing on screen is wrong
./bin/run lab01 --shot shots/lab01.png # look at the PNG
```

**Stretch:** add `draw.bar` driven by `oscillate(0.25)`, and a `draw.panel` with
a `title:` whose text sits in the returned rect.

---

### 2. Coordinate duel *(~45 min)*

**Teaches:** the two coordinate systems, `place:`, anchors, `Geom`,
`columns`, `row_at`, `inset`.

This assignment exists to make one idea unmissable: **top-level `x:`/`y:` are
absolute pixels with a bottom-left origin, and `place:` positions everything as
a fraction of the current bounds.**

Create `carts/lab02`.

**Spec**

1. Draw the *same* row of three 80×80 rects three ways:
   - by absolute `x:`/`y:`,
   - by `top:`, so the row hangs from the top of the screen,
   - inside `draw.within { ... }` with `place: { x: 0.5, anchor_x: 0.5, ... }`.
2. Inside a `draw.within bounds do ... end` block, use `place:` with **fractional**
   `w:`/`h:` and show that `w: 0.5` is half the bounds width.
3. Demonstrate the override rule: pass `place:` *and* a top-level `w: 32`, and
   prove the rect is 32px, not 32% — that is the escape hatch sprites and text
   need.
4. Use `columns(screen_rect, 8, 6)` to lay out an 8-column strip, and
   `row_at(top_y, index, width, line_h)` to place list rows counting downward
   from a top edge.
5. Nest two `draw.within` calls and print `draw.bounds[:w]` at each level.
6. Wrap one `draw.within` block in a `begin`/`rescue` that raises, then print
   `draw.bounds[:w]` again — bounds must be restored even when the block blows up.

**Verify**

```sh
./bin/run lab02 --shot shots/lab02.png
```

Then answer, in a comment at the top of the file: which of rows 1–3 is the one
you would use for a HUD, and why.

**Stretch:** wrap everything in a `draw.within screen_rect` so the whole
layout survives a resolution change.

---

### 3. HUD kit *(~45 min)*

**Teaches:** composition, returning rects, widgets as layout primitives.

Create `carts/lab03`. Build a small reusable HUD toolkit at the bottom of the
cart class, then use it.

**Spec**

1. Write these private helpers, each taking one options hash and returning a
   rect, exactly like the console's own helpers:
   - `hud_panel(x:, top:, w:, h:, title:)` — a titled panel using `ui.panel`
     plus `draw.text` positioned by `top:` relative to the panel's top edge.
   - `hud_stat_row(x:, top:, w:, label:, value:)` — label on the left, value
     right-aligned on the same row.
   - `hud_slots(x:, top:, w:, count:, size:, filled:)` — `count` squares via
     `columns`, filled ones `:accent`, empty ones `:muted`.
2. Use all three from `render`, with a `ui_store` counter that changes over time
   (`every 45 { ... }`), so the HUD visibly animates.
3. Lay the HUD out with `top:` exclusively. No raw `y:` anywhere in the file.
4. Print the rect each helper returns, so you can see that they compose.

**Verify**

```sh
./bin/run lab03 --hud --shot shots/lab03.png
```

**Stretch:** make the whole HUD adapt to `screen[:w]` by placing it with
`draw.within strip(0, 96)`, and give it a translucent backdrop with
`draw.rect ..., color: :shadow`.

---

## Tier 2 — Gameplay

### 4. Entity arcade *(~90 min)*

**Teaches:** the entity store — `spawn`, `each_entity`, `move`, `colliding`,
`despawn_if`, `entity_count`, and `kind` as both query tag and animation key.

Create `carts/lab04`. A ship, drifting rocks, bullets, one score number.

**Spec**

1. Define plain classes that describe *defaults*, not behaviour:
   ```ruby
   class Rock
     def self.defaults
       { kind: :rock, w: 32, h: 32, hp: 1 }
     end
   end
   ```
   `spawn Rock, x: 100, y: 100, sprite: :rock` should pick those up.
2. Spawn a player. Drive it with `input.axis_x` / `input.axis_y` through
   `move`, and keep it on screen with `clamp_inside`.
3. On `:accept`, spawn a bullet at the player with a velocity aimed along the
   current `axis_x`/`axis_y`.
4. Rocks drift and **wrap around the screen edges**. Bullets are despawned with
   `despawn_if { |e| ... }` the moment they leave — not by checking in `update`.
5. `colliding(bullet, :rock)` — despawn the bullet, decrement the rock's `hp`,
   despawn the rock at 0, add to the score, and play `sfx` if one is registered.
6. Show live counts with `entity_count(:rock)` and `entity_count(:bullet)`, so
   a leak is visible rather than theoretical.
7. Draw everything with `draw_entity`.

**Verify**

```sh
./bin/run lab04 --ticks 600 --shot shots/lab04.png
```

Watch the entity counts for a minute: they must return to a steady state, never
climb forever.

**Stretch:** give rocks a `kind` that matches a real sprite folder and watch
animation pick it up for free (see `carts/arcade/sprites/hero/idle/`).

---

### 5. Timing and camera *(~60 min)*

**Teaches:** `tween`, `tween_all`, `after`, `every`, easings, camera follow /
shake / zoom / bounds, and animation `lock:`.

Create `carts/lab05`.

**Spec**

1. Make a larger world than the screen (`camera.bounds = { x: 0, y: 0,
   w: 2000, h: 1200 }`) and keep the player inside it.
2. `camera.follow player`, and wrap every world-space draw in
   `camera.apply do ... end` — world inside, HUD outside.
3. On firing: `camera.shake 6, 12` for the hit, and `tween` the player's `flash`
   property with `ease: :out`.
4. Use all four of:
   - `tween entity, :x, to: 400, in: 30`
   - `tween_all entity, %i[x y], from: [..], to: [..], in: 60`
   - `after 30 { ... }` — a delayed one-shot
   - `every 60, immediate: true { ... }` — a repeating cadence
5. `after 60 { zoom_out }` where `zoom_out` tweens `camera.zoom` with
   `ease: :in_out`, then chains back after another `after`.
6. Sweep the easings: draw seven small squares, one per entry in
   `Console::Tween::EASINGS`, each running `tween_all` with a different `ease:`,
   all started on the same frame. (`elastic` overshoots past 1 on purpose — show
   that rather than hiding it.)

**Verify**

```sh
./bin/run lab05 --hud --shot shots/lab05.png
```

**Stretch:** every easing should finish at the same value after the same number
of ticks. Verify it, and write down what proves it.

---

### 6. Input lab *(~45 min)*

**Teaches:** the one action vocabulary, pointer and device detection, and the
supported way to add your own action.

Create `carts/lab06`. A live readout of everything the console knows about
input, plus one action of your own.

**Spec**

1. Draw a grid of cells, one per entry in `Console::Input::ACTIONS`, lighting up
   on `input.held?(:action)` and labelling on `input.pressed?(:action)`.
2. Show `input.axis_x` / `input.axis_y` as two live bars. They are `-1.0..1.0`,
   not pixels.
3. Show `input.pointer` (`x`, `y`, `down`, `pressed`, `released`) and
   `input.last_device`.
4. Draw a clickable rect and prove `input.clicked?(rect)` fires only when the
   press went down *inside* it — then store the hit count in `ui_store`.
5. Add your own action to `Console::Input::ACTIONS` — `:fire` bound to, say,
   the `z` key / right shoulder — and use it exactly like a built-in one. Do not
   reach for `args.inputs.key_down?` directly.
6. Handle typed text: `start_text_input`, then echo `input.typed` into a label.

**Verify**

```sh
./bin/run lab06 --shot shots/lab06.png
```

**Stretch:** make the cells keyboard-, gamepad- and pointer-navigable so the
same cart is usable with no keyboard at all, and prove it works with
`input.last_device` switching the on-screen hints.

---

## Tier 3 — Structure

### 7. Scene stack *(~60 min)*

**Teaches:** `scene`, `goto`, `push_scene`, `pop_scene`, `unwind`,
`scene_data`, `on_enter`/`on_leave`, and that the hook is `render`.

Create `carts/lab07` with four scenes: `title`, `play`, `pause`, `gameover`.

**Spec**

1. Define a cart class that registers its scenes in `setup`. Once a cart
   defines scenes, `update` is **not** called — move that logic into a scene.
2. Each scene implements any of `enter`, `update`, `render`, `leave`. Note the
   name: a scene that defines `draw` shadows the console's rendering object.
3. `title` → `play` with `goto`. In `play`, `:pause` calls `push_scene :pause`
   so the game keeps rendering underneath, and `:cancel` in pause calls
   `pop_scene`.
4. `on_enter(:play) { music :title }` and `on_leave(:play) { stop_music }`.
5. Prove persistence: `scene_data[:play][:score]` survives `push_scene` /
   `pop_scene` round trips, and `scene_data(:title)` reaches *another* scene's
   hash.
6. `gameover` uses `unwind` to go back to the first scene rather than
   `goto :title`.
7. Call `goto` from inside `update` and show that the frame completes cleanly —
   scene changes commit at the end of the frame.

**Verify**

```sh
./bin/run lab07 --scene play     # skip the front door while iterating
./bin/run lab07 --hud
```

**Stretch:** a fade transition between scenes, using `tween` on a `fade`
property in `scene_data` and honouring it in `render`.

---

### 8. Settings menu *(~60 min)*

**Teaches:** every widget, the one-options-hash rule, and `ui_store` as the
widget backing store.

Create `carts/lab08` — a real options screen, and treat
`carts/widgets/app/widgets.rb` as a reference, not a thing to copy.

**Spec**

1. Lay out, using `top:` only: `ui.label`, `ui.chip`, `ui.panel`, `ui.bar`,
   `ui.pips`, `ui.slider`, `ui.button`, `ui.checkbox`, `ui.menu`, `ui.card`.
2. Act on return values — this is the whole widget contract:
   ```ruby
   b = ui.button x: 0, top: 420, w: 160, text: 'START'
   goto :play if b[:clicked]

   m = ui.menu x: 0, top: 510, w: 300, items: %w[PLAY QUIT]
   goto :play if m[:clicked] == 'PLAY'

   s = ui.slider x: 0, top: 380, w: 200, key: 'volume'
   music_gain s[:value] / 100.0
   ```
3. Wire `ui.checkbox` and `ui.slider` to real state: the checkbox toggles the
   HUD, the slider sets `music_gain`, a `ui.menu` sets the difficulty.
4. Every keyed widget persists under `ui_store` — read `ui_store` back and
   display it, so persistence is visible.
5. Navigate with the pointer **and** the keyboard/gamepad: focus a menu, then
   `:accept` activates. `ui.card` dims the screen behind it.
6. `toggle_mute` on a button, and reflect muted state in a `ui.chip`.

**Verify**

```sh
./bin/run lab08 --shot shots/lab08.png
```

---

## Tier 4 — World, assets, tests

### 9. Platformer *(~90 min)*

**Teaches:** LDTK level loading, `body`, gravity, collision, and the console's
own coordinate handling.

Copy the LDTK cart's level into your own so you own it — a published cart
stages its own directory alone:

```sh
mkdir -p carts/lab09/maps
cp carts/ldtk/maps/Level_0.ldtk carts/lab09/maps/
```

**Spec**

1. `map = load_map 'maps/Level_0.ldtk'`, then `spawn_level map`.
2. `body = body entity: @ship, gravity: 0.4`. Drive `body.vx` from
   `input.axis_x`, and jump with `body.jump 9 if input.pressed?(:accept) &&
   body.grounded?`. Call `body.update map.solids` every frame.
3. Track the three one-frame signals and act on each differently:
   `body.landed?` (play a sound, spawn dust), `body.wall?` + `body.wall_dir`
   (slide, do not stop), `body.ceiling?` (bonk).
4. Show `body.fall_distance` in the HUD, and enable `step_height: 16` so the
   player walks over low ledges.
5. Prove you understand the loader: print what an entity actually became.
   `map.entities_of('Enemy').first` should be a Hash whose LDTK
   `__identifier` became `:kind`, whose `MaxSpeed` became `:max_speed`, whose
   Int field `3` arrived as an Integer, and whose Point field became
   `{ x:, y: }`.
6. Note that LDTK is top-left with `y` growing *down* while the console is
   bottom-left. Positions are flipped on load — verify it by finding a platform
   near the top of the level and confirming it ends up at a *high* `y`.
7. `camera.bounds` from the map's own dimensions so the camera cannot show the
   void outside the level.

**Verify**

```sh
./bin/run lab09 --ticks 600 --shot shots/lab09.png
```

**Stretch:** make a pass-through platform. `OneWay` (or `one_way_value: 2` on
`load_map`) is a solid you can jump up through and land on from above.

---

### 10. Asset discipline *(~45 min)*

**Teaches:** cart-relative paths, the sprite index, procedural generation, and
why a borrowed asset breaks a published build.

Create `carts/lab10`.

**Spec**

1. Generate every texture you use with `auto_sprite`, so the cart needs no art:
   try all six patterns — `:solid :checker :stripes :frame :circle :ring`.
2. Put two real PNGs in `carts/lab10/sprites/` and reach them **by name** with
   no registration at all — borrow some from a cart that owns them:
   ```sh
   mkdir -p carts/lab10/sprites/misc
   cp carts/selftest/sprites/star.png carts/lab10/sprites/star.png
   cp carts/selftest/sprites/blue.png carts/lab10/sprites/misc/star.png
   ```
   Now `sprite(:star)` resolves with nothing declared, and the nested
   `sprites/misc/star.png` is reachable as `:star` *and* as `:'misc/star'`.
   Note the deliberate collision — both files register the short key `star`, so
   only one of them wins. Read `Console::Sprites#walk`
   (`app/console/sprites.rb:52`) to find out which, then write a comment saying
   so. Do not guess: this is the mechanism behind every "my sprite is the wrong
   one" bug.
3. Declare short names via `self.assets` for the rest:
   `{ sprites: { hero: 'sprites/hero.png' }, sounds: { jump: '..' },
      music: { title: '..' } }`
4. Create `carts/lab10/data/config.json`, read it with
   `DR.read_file asset('data/config.json')`, and let the values actually
   configure the cart (speed, colour, count).
5. Write `data/` yourself — that is the console's one job `asset` does for you.
6. **Finish with `shared_assets` empty.** Then prove the cart packages:
   ```sh
   ./bin/run lab10 --ticks 300
   ./bin/publish-cart lab10 --dry-run
   ```
   If it borrows anything from the console root, the dry run refuses to
   package it. Fix it by moving the file into the cart.

**Verify**

```sh
./bin/publish-cart --list
./bin/publish-cart lab10 --dry-run
```

**Stretch:** make a missing sprite *loud on purpose* — ask for a name that does
not exist, read the on-screen warning, then explain in a comment why a
placeholder plus a warning beats a crash.

---

### 11. Write the tests *(~60 min)*

**Teaches:** `Console::Test` — the console's own harness, usable for your code.

The console runs its suite **inside the real DragonRuby runtime**, against the
real renderer and the real mruby build. Add your file next to the existing
suites:

```
carts/selftest/app/lab_suite.rb
```

**Spec**

1. A suite class that does `include Console::Test`, with `test '...' do ... end`
   blocks. Assertions available: `assert`, `refute`, `assert_equal`,
   `refute_equal`, `assert_almost_equal`, `assert_nil`, `assert_not_nil`,
   `assert_includes`, `refute_includes`, `assert_between`, `assert_raises`.
2. Write tests for **your own cart's logic** from assignments 4, 5 and 9:
   - entity spawn defaults are applied, and `despawn_if` removes exactly the
     right ones,
   - a tween lands exactly on its target value — pass an explicit
     `now:` so the test does not sleep through real frames,
   - `body` lands on a solid and does not fall through it.
3. Add a suite for `Console::Geom` you wrote yourself: pick five helpers from
   `app/console/geom.rb` and cover each edge case, including the ones the README
   calls out (`contains?` is half-open and excludes the far edge; `columns`
   divides width *after* subtracting gaps).
4. Each `test` block runs against a fresh instance, so use `setup` for shared
   state rather than instance variables leaking between tests.
5. Write one test that **fails on purpose**, read the failure report, then fix
   it. Knowing what a failure looks like is the point of that one.

**Verify**

```sh
./bin/run-test
# CONSOLE_TEST_STATUS=PASS TESTS=... ASSERTIONS=... FAILURES=0
```

`./bin/run-test` exits non-zero on failure, so it drops straight into CI.

> Watch out: a file in `carts/selftest/app/` is required during boot. If it
> raises at load time it takes the whole console down, not just your suite.

**Stretch:** one test that mutates global asset scope (`Console::Assets.boot`),
restores it in an `ensure`, and rebuilds the sprite index — the pattern the
`AssetsSuite` uses in `carts/selftest/app/selftest.rb`.

---

## Capstone — one cart, everything *(~half a day)*

Build `carts/arcade2`: a small but complete game, using every subsystem.

**Required**

- **Scenes:** `title` → `play` → `gameover`, with `push_scene :pause` over
  `play` and `unwind` back to the title.
- **World:** entities by `kind`, `camera.follow`, `camera.bounds`, and shake on
  hit — world drawn inside `camera.apply`, HUD outside.
- **Feel:** `after`/`every` for wave scheduling, `tween` for juice, an
  `animate ... lock:` death animation that cannot be interrupted.
- **UI:** a `ui.bar` health readout, a `ui.menu` title screen, and a `ui.slider`
  volume control that really changes `music_gain`.
- **Input:** actions only — no direct `args.inputs` lookups anywhere.
- **Audio:** `music` on `on_enter(:play)`, `stop_music` on `on_leave(:play)`,
  and sfx that degrade silently when unregistered.
- **Assets:** every texture generated or owned. `shared_assets` is empty.
- **Tests:** a suite in `carts/selftest/app/` covering your scene transitions
  and your wave scheduler.

**Done when**

```sh
./bin/run-test                                # still green, including your new tests
./bin/smoke                                   # every cart boots, including arcade2
./bin/run arcade2 --ticks 900 --shot shots/arcade2.png
./bin/publish-cart arcade2 --dry-run          # packages, no borrowed assets
```

**Then, as the real exam:** read your own cart's `app/` directory and list every
API call you used that you could now replace with something the console already
had. That list is the API you actually learned.