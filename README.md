# The Cartridge Console

A fantasy console for [DragonRuby](https://dragonruby.org): a small, opinionated
library that turns a **cart** — one Ruby file — into a running game.

```ruby
# app/carts/space.rb
TITLE = 'space rocks'

class Space
  def setup
    @ship = spawn :ship, kind: :hero, x: 640, y: 480, w: 24, h: 24
    animate @ship, :idle, fps: 8
  end

  def update
    each_entity do |e|
      move e, vx: input.axis_x * 4, vy: input.axis_y * 4
    end
  end

  def render
    draw_entity @ship
  end
end
```

```sh
./run --cart space
```

That is the whole idea. No pixel editor, no sound chip editor — just a small API
surface and a lot of helpers, so you can get to a playable MVP before you have
art, and keep going when you do.

Verified against **DragonRuby 7.21**.

---

## Getting started

The console is an ordinary DragonRuby game directory.

```sh
cd console

./run                  # boot the default cart
./run --cart hello     # boot a specific cart
./run --list           # what carts exist
./run --hud            # start with the debug overlay on

./run-test             # run the self test (exits non-zero on failure)
./smoke                # boot every cart headlessly and report failures
```

Carts are selected by `--cart <name>`, then `$CART`, then the default. To debug
one scene of a game without playing through the front door:

```sh
./run --cart arcade --scene play
```

### Switches

| Switch | Effect |
|---|---|
| `--cart <name>` | which cart to boot |
| `--list` | print the available carts and exit |
| `--selftest` | run the self test, print a report, exit |
| `--scene <name>` | jump straight into a named scene |
| `--hud` | start with the debug overlay on |
| `--ticks <n>` | quit after n frames (headless smoke runs) |
| `--shot <path>` | write a PNG of the last frames, then quit |

On a headless machine, wrap the console in `xvfb-run -a`.

---

## Layout

```
console/
├── app/
│   ├── main.rb              entry point: requires the library, runs the loop
│   ├── console/             the library
│   │   ├── core.rb          the Console object + the cart-facing API
│   │   ├── cart_loader.rb   finds a cart, requires it, boots
│   │   ├── geom.rb          rect maths, top-down layout helpers
│   │   ├── draw.rb          rendering helpers
│   │   ├── input.rb         one action vocabulary
│   │   ├── sprites.rb       name -> texture, plus procedural generation
│   │   ├── animation.rb     frame animations and an animation state machine
│   │   ├── audio.rb         sfx and music
│   │   ├── camera.rb        world/screen transform
│   │   ├── tween.rb         tweens, `after`, `every`
│   │   ├── scene.rb         scene stack and transitions
│   │   ├── entity.rb        the entity store
│   │   ├── ui.rb            widgets
│   │   ├── palette.rb       colors and style defaults
│   │   ├── str.rb           string helpers (mruby has no Regexp)
│   │   ├── testing.rb       the self-test harness
│   │   └── version.rb       the console's version string
│   └── carts/               one file per cart
├── sprites/                 assets, discovered and indexed automatically
├── shots/                   screenshots written by --shot
├── run / run-test / smoke
└── metadata/game_metadata.txt
```

---

## The cart contract

A cart is one file under `app/carts/`. Define a class (or a module) named after
the file and implement whichever hooks you need. All of them are optional.

```ruby
TITLE = 'my game'          # shown by --list

class Mygame
  # Optional: short names for assets. Anything under ./sprites is already
  # reachable by name without this.
  def self.assets
    { sprites: { hero: 'sprites/hero.png' },
      sounds:  { jump: 'sounds/jump.wav' },
      music:   { title: 'sounds/title.ogg' } }
  end

  def setup;  end          # once, at boot
  def update; end          # every frame (only when the cart defines no scenes)
  def render; end          # every frame, always last: use it for a HUD
end
```

A cart with scenes uses them *instead of* `update`, and `render` still runs last:

```ruby
class Mygame
  def setup
    scene :title, TitleScene     # register
    scene :play, PlayScene
    goto :title                  # go
  end
end
```

Every method in `Console::API` is available as a bare call inside a cart and
inside its scenes. Scene classes get it automatically when registered.

---

## The API

### Scenes

```ruby
scene :play, PlayScene    # register a scene
goto :play                # replace the stack
push_scene :pause         # overlay, keep the scene underneath
pop_scene                 # back
unwind                    # back to the first scene
current_scene             # => :play
scene_data                # this scene's persistent Hash
scene_data(:play)         # another scene's Hash

on_enter(:play) { music :game }
on_leave(:play) { stop_music }
```

A scene may implement `enter`, `update`, `render` and `leave`. Scene changes are
committed at the end of the frame, so calling `goto` from inside `update` never
leaves the frame half-applied.

> The hook is `render`, **not** `draw`: `draw` is the console's rendering object
> (`draw.rect`, `draw.sprite`). A scene that defined `draw` would shadow it.

### Drawing

```ruby
draw.rect   x: 0, y: 0, w: 100, h: 50, color: :accent
draw.border x: 0, y: 0, w: 100, h: 50, color: :muted
draw.panel  x: 0, y: 0, w: 100, h: 50, title: 'STATS'
draw.text   'hello', x: 0, y: 0, size_px: 20, color: :text
draw.sprite path: :hero, x: 0, y: 0, w: 32, h: 32
draw.line   0, 0, 100, 100, :white, 2
draw.grid   x: 0, y: 0, w: 200, h: 100, cols: 8, rows: 4
draw.bar    { x: 0, y: 0, w: 100, h: 10 }, 5, 10
```

Every method returns the rect it drew, so calls compose and can be hit-tested
without recomputing geometry.

**Two coordinate systems.** Top-level `x:`/`y:` are absolute pixels, with `y:`
measured from the *bottom* (DragonRuby's origin). `place:` positions and sizes
everything as a *fraction* of the current bounds:

```ruby
draw.within ui.panel(x: 0, top: 80, w: 400, h: 200) do
  draw.text 'centred', place: { x: 0.5, y: 0.5, anchor_x: 0.5, anchor_y: 0.5 }
end
```

Inside `place:`, `x`, `y`, `w` and `h` are all fractions. A top-level `w:`/`h:`
overrides with absolute pixels, which is what sprites and text want.

**Top-down layout.** Counting up from the bottom edge is nobody's mental model
for a menu, so widgets and draw calls accept `top:` (pixels below the top of the
screen) as an alternative to `y:`:

```ruby
ui.panel x: 40, top: 96, w: 420, h: 230     # top edge is 96px from the top
draw.within strip(0, 56) { ... }             # a 56px bar across the top
row_at 96, 2, 200, 20                        # the third row of a list
```

### UI

Every widget takes **one options hash** and returns a Hash describing what
happened.

```ruby
ui.label    x: 0, top: 20, text: 'SCORE 100'
ui.chip     x: 0, top: 20, text: 'hp 3'
ui.panel    x: 0, top: 80, w: 400, h: 200, title: 'STATS'
ui.bar      x: 0, top: 300, w: 200, value: hp, max: max_hp
ui.pips     x: 0, top: 340, w: 200, value: 3, max: 5
ui.slider   x: 0, top: 380, w: 200, key: 'volume'
ui.button   x: 0, top: 420, w: 160, text: 'START'
ui.checkbox x: 0, top: 470, key: 'grid', text: 'grid'
ui.menu     x: 0, top: 510, w: 300, items: %w[PLAY QUIT], key: 'main'
ui.card     w: 520, h: 300          # centred modal, dims the screen
ui.hud                           # the debug overlay
```

Each returns `:rect` plus what matters:

```ruby
b = ui.button x: 0, y: 0, w: 160, h: 40, text: 'START'
goto :play if b[:clicked]                    # pointer or :accept while focused

m = ui.menu x: 0, y: 0, w: 300, items: items
goto :play if m[:clicked] == 'PLAY'          # also m[:index], m[:items]

s = ui.slider x: 0, y: 0, w: 200, key: 'volume', min: 0, max: 100
# s[:value] is persisted in ui_store under :key
```

Widgets are pointer- and keyboard/gamepad-navigable: hover a button or focus a
menu and `:accept` activates it.

### Input

One vocabulary across keyboard, gamepad and touch. A cart asks
`input.pressed?(:accept)` and never has to care which device the player is on.

```ruby
input.held?(:up)         # arrows + WASD + dpad + left analog
input.pressed?(:accept)  # space / enter / gamepad a (Switch Pro aware)
input.released?(:cancel)
input.axis_x              # -1.0 .. 1.0
input.pointer             # {x:, y:, down:, pressed:, released:}
input.clicked?(rect)      # went down inside rect
input.last_device         # :keyboard / :controller / :mouse
input.typed               # requires start_text_input
```

Actions: `:up :down :left :right :accept :cancel :pause :action_1 :action_2
:action_3 :action_4 :debug_toggle`. Add your own by extending
`Console::Input::ACTIONS`.

### Entities

Entities are plain Hashes with a unique `id`, a `kind` tag and a rect — which
means they are already valid DragonRuby primitives.

```ruby
ship = spawn :ship, kind: :hero, x: 100, y: 100, w: 24, h: 24, sprite: :hero

each_entity(:enemy) { |e| move e, vx: e[:vx], vy: e[:vy] }
entities_of(:bullet)
colliding(ship, :enemy).each { |e| despawn e }
despawn_if { |e| e[:y] > 900 }
entity_count(:enemy)

draw_entity e            # resolves animation, tint, alpha, flips
```

### Animation

Sprite animations are discovered from the filesystem: an entity of `kind: :hero`
playing `:run` looks in `sprites/hero/run/*.png`, ordered by filename number.

```ruby
animate entity, :run                     # loops
animate entity, :hit, repeat: false      # one-shot
animate entity, :die, lock: 24           # uninterruptible for 24 ticks
animate entity, :walk, sheet: 'hero.png', frame_w: 16, frame_h: 20,
                 frames: 6               # a sprite sheet, cropped

animating?(entity, :run)
anim_done?(entity)
stop_anim(entity)
```

The `lock:` option is the piece samples otherwise hand-roll ~200 lines for: a
death animation cannot be cut short by a flinch.

### Sprites, and having no art yet

```ruby
sprite :hero                            # resolve a name
auto_sprite :crate, 24, 24, :warn, :frame  # generate it if there is no file
```

`auto_sprite` is the reason a cart is playable on day one. Patterns: `:solid`,
`:checker`, `:stripes`, `:frame`, `:circle`, `:ring`. Generated textures are real
textures, addressable by symbol.

Names come from the `./sprites` tree (indexed recursively at boot, so
`sprites/misc/star.png` is reachable as `:'misc/star'` and `sprite(:star)`), plus
anything registered through `self.assets`.

### Audio

```ruby
sfx :shoot
sfx :hit, pitch: 0.8, gain: 0.5
music :title
music_gain 0.4
stop_music
mute
```

Music is tracked under one key, so calling `music` again swaps the track instead
of stacking loops. Unregistered sounds are skipped rather than crashing.

### Camera

```ruby
camera.follow entity
camera.bounds = { x: 0, y: 0, w: 1600, h: 900 }
camera.shake 6, 12
camera.zoom = 1.5

camera.apply do
  each_entity { |e| draw_entity e }
end
```

Everything inside `apply` is world space; everything outside is screen space.
That is the usual split: world inside, HUD after.

### Tweens and scheduling

```ruby
tween entity, :x, to: 400, in: 30
tween entity, :alpha, to: 0, in: 30, ease: :out
tween_all entity, %i[x y], from: [0, 0], to: [100, 100], in: 60

after 30 { spawn Enemy, x: 100, y: 100 }
every 60, immediate: true { next_wave }
```

Easings: `:linear :in :out :in_out :smooth :elastic :bounce`.

### Geometry

```ruby
center(rect)          # geometric centre (not the anchor point)
overlaps?(a, b)
inside?(rect, x, y)
percent(value, max)
columns(rect, 8, 4)
inset(rect, 10)
clamp_inside(rect, bounds)
```

### Random

```ruby
rand_int(1, 6)
rand_between(-1.5, 1.5)
pick(array)
chance(0.3)
oscillate(0.4)        # a looping 0.0..1.0 ramp
sine(1.0, 0, 20)      # centred oscillation
```

---

## Carts included

| Cart | What it shows |
|---|---|
| `hello` | the smallest interesting cart; no assets, generated textures |
| `arcade` | a playable MVP: scenes, waves, shooting, camera, shake, tweens, pause overlay, game over |
| `widgets` | every UI widget, laid out as a live reference |
| `selftest` | the console's own test suite |

Screenshots of each live in `shots/` (regenerate with `--shot`).

---

## Tests

```sh
./run-test
```

116 tests / 1303 assertions, executed **inside the real DragonRuby runtime** —
against the real renderer, the real output collections and the real mruby build,
not a stand-in. The suite covers geometry, strings, palettes, the sprite index
and procedural generation, drawing and coordinate systems, tweens and easing,
scenes, entities, animation, the camera, widgets, input, and the runtime wiring.

It prints a machine-readable summary:

```
CONSOLE_TEST_STATUS=PASS TESTS=116 ASSERTIONS=1303 FAILURES=0
```

`./smoke` additionally boots every cart headlessly and fails if any raises.

---

## Notes on mruby

DragonRuby embeds **mruby 3.0**, which is not Ruby. The console is written
against what mruby actually provides, and a few things are worth knowing because
they shaped the design:

- **No `Regexp`.** All string handling goes through `Console::Str`.
- **`outputs.solids` is deprecated.** Fills are emitted as sprites with
  `path: :solid`, which shares the sprite pipeline's texture caching.
- **A trailing `key: value` list binds to the *first* optional parameter**, not
  the last. Every widget and draw helper therefore takes exactly one options
  hash — otherwise `ui.panel x: 0, y: 0, w: 200, h: 200` silently puts the whole
  hash into `x`.
- **The origin is bottom-left**, so `y:` counts up from the bottom. Widgets and
  draw calls take `top:` to avoid the mental arithmetic.
- **`DR.list_files` is not recursive**, so the sprite index walks directories
  itself using `DR.stat_file`.
- **`controller_one.key_down?(:accept)` raises** — `accept`/`cancel` are
  top-level properties, not valid dynamic key lookups. The console resolves the
  physical button and swaps it on a Switch Pro pad.
- **DragonRuby owns the `--test` switch**, so the console's own runner is
  `--selftest`.

## License

The console is yours. DragonRuby itself is licensed by DragonRuby LLC; see
`../eula.txt`.