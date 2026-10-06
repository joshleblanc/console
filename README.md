# The Cartridge Console

A fantasy console for [DragonRuby](https://dragonruby.org): a small, opinionated
library that turns a **cart** — one directory — into a running game.

```ruby
# carts/space/app/space.rb
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

Carts are selected by `--cart <name>`, then `$CART`, then the default. A
*published* build instead pins one cart, which outranks both of the above — see
[Publishing a single cart](#publishing-a-single-cart). To debug one scene of a
game without playing through the front door:

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

## Publishing a single cart

`dragonruby-publish` packages a whole game directory, and this directory holds
*every* cart under `carts/`. Pointed at the console, it would ship the
selftest, the widgets gallery and the arcade cart all inside one build.

So publish through `./publish-cart`, which stages a throwaway directory first:

```sh
./publish-cart --list                  # carts, with the titles that will publish
./publish-cart arcade                  # package arcade for linux-amd64
./publish-cart arcade --dry-run        # stage + verify, package nothing
./publish-cart arcade --platforms=html5,linux-amd64
```

It stages `builds/cart-staging/<cart>/` containing the console library, the
cart directory (code *and* the sprites, sounds, maps and data it owns),
metadata derived from the cart's `TITLE`, and an entry point that **pins** the
cart — then packages that directory. Artifacts land in `../builds/`.

### Metadata

`metadata/game_metadata.txt` is the one file a cart genuinely cannot own: the
engine reads it from the **game root** (the path is hardcoded in DragonRuby), so
every cart shares it while you develop. Running `--cart arcade` in a checkout
therefore still identifies as `Console` — that is DragonRuby, not the console.

Publishing resolves it per cart. A cart that ships its own
`carts/<name>/metadata/game_metadata.txt` uses that verbatim — its own identity,
its own icon, and its own engine settings. Otherwise the console's file is
inherited and only `gameid` and `gametitle` are rewritten, from the cart name and
the cart's `TITLE`, so the published title and `--list` can never disagree.

The important part is what is *not* rewritten. DragonRuby loads the whole file
into `Cvars["game_metadata.*"]`: the first six lines are read positionally
(`devid`, `devtitle`, `gameid`, `gametitle`, `version`, `icon`), and every key
after them is read by name and decides real behaviour — `hd`, `highdpi`,
`orientation`, `aspect_mode`, `sprites_directory`. So the staged file is the
console's file with those fields edited in place, never a freshly written
six-line file. Writing one drops the rest, and the published build quietly stops
matching the checkout you tested: a `highdpi=true` in the console metadata used to
build at lowdpi with nothing to say so.

A cart's `metadata/icon.png` also wins over the console's, which is how each cart
ends up with its own icon instead of the console's.

These environment variables override individual fields:

| Variable | Default |
|---|---|
| `CART_VERSION` | the metadata's `version` |
| `CART_GAMEID` | the cart name |
| `CART_GAMETITLE` | the cart's `TITLE` |
| `CART_DEVID` / `CART_DEVTITLE` | the metadata's `devid` / `devtitle` |

### Why only one cart

Two independent checks, because "trust the copy loop" is how the wrong game
gets published:

1. **A script-side guard** reads the staged directory back off disk and refuses
   to package unless it holds exactly one cart directory, it is the requested
   one, the generated `main.rb` pins it, and nothing in the tree requires
   another cart. It exits non-zero rather than shipping a contaminated build.

2. **A runtime pin.** `Console::CartLoader#pin` makes the choice unrecoverable
   at runtime: the pin outranks `--cart` and `$CART`, and a pinned cart that is
   missing aborts the boot instead of falling back to the default. A typo can
   never ship a different game than the one you built.

Staging is rebuilt from scratch on every run, so a deleted cart cannot linger
in a build.

### Why a cart has to own its assets

The staged build contains the cart directory and nothing else — no console-root
starter art to fall back on. That makes a borrowed asset a file that is simply
absent from the package, which is the kind of bug that only shows up on a
device. So `publish-cart` also reads the staged cart's referenced asset paths
back and refuses to package when one does not resolve inside it:

```
publish-cart: ABORT 'arcade' uses assets it does not own:
    sprites/hero/idle/0.png  (missing from .../cart-staging/arcade/carts/arcade)
    move them into carts/arcade/, or the build will not have them
```

`shared_assets` tells the same story from inside a running cart.

> `dragonruby-publish` resolves a relative game directory against the
> DragonRuby root it ships in, and fails to read metadata from an absolute one.
> The script handles this for you.

---

## Layout

```
console/
├── app/
│   ├── main.rb              entry point: requires the library, runs the loop
│   ├── console/             the library
│   │   ├── core.rb          the Console object + the cart-facing API
│   │   ├── cart_loader.rb   finds a cart, requires it, boots
│   │   ├── assets.rb        resolves a cart-relative path to a real one
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
│   │   ├── map.rb           LDTK level loading
│   │   ├── body.rb          kinematic platformer body
│   │   ├── testing.rb       the self-test harness
│   │   └── version.rb       the console's version string
├── carts/                   one directory per cart
│   └── space/
│       ├── app/space.rb     the cart, plus any code files beside it
│       ├── sprites/         its own art
│       ├── sounds/          its own sounds and music
│       ├── maps/            its own LDTK levels
│       └── data/            anything else it reads
├── sprites/                 console starter art: the fallback when a cart has
│                            no file of its own
├── shots/                   screenshots written by --shot
├── run / run-test / smoke
├── publish-cart             package exactly one cart
└── metadata/game_metadata.txt
```

---

## The cart contract

A cart is a directory under `carts/`, and its entry file is `app/<name>.rb`.
Define a class (or a module) named after the cart there, and implement whichever
hooks you need. All of them are optional.

```ruby
TITLE = 'my game'          # shown by --list

class Mygame
  # Optional: short names for assets. Anything under the cart's own sprites/
  # is already reachable by name without this.
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

### Paths are cart-relative

Every path a cart writes is relative to **its own directory**:

```ruby
asset 'sprites/hero.png'   # => 'carts/mygame/sprites/hero.png'
asset 'data/level.json'    # => 'carts/mygame/data/level.json'
```

This needs no ceremony anywhere else either: `self.assets`, `sprite`,
`draw_sprite`, `animate ..., sheet:`, `load_map`, sounds and music all resolve
the same way, because the console rewrites a path when it hands it to
DragonRuby. So a cart never hardcodes its own name, and two carts can each have
a `sprites/hero.png` without seeing each other's.

There is exactly one fallback: a file that is not inside the cart is looked for
at the console root, which is how the console ships starter art for a brand-new
cart. Every borrow is logged at boot, and a cart can ask for the list:

```ruby
assets_root      # => 'carts/mygame'
shared_assets    # => ['sprites/dragon-0.png']  borrowed, should be moved in
```

A cart that owns its assets has none — and that is the state you want before
publishing, because `./publish-cart` stages the cart directory alone, so
anything borrowed would simply be missing from the build.

### More than one file

The entry file is required first and the rest of `app/*.rb` follows, so a cart
can be split up with no wiring:

```
carts/space/app/space.rb     # the cart
carts/space/app/entities.rb  # required automatically
```

Sub-directories are the cart's own to require
(`require 'carts/space/app/boss/boss'`). Only the booted cart's files are ever
required, so a cart broken mid-edit cannot stop the console from starting.

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

### Assets

```ruby
asset 'data/level.json'    # => 'carts/space/data/level.json'
assets_root                # => 'carts/space'
shared_assets              # => [] -- assets borrowed from the console root
```

The console resolves sprites, sounds, music, animation frames and maps for you;
`asset` is for everything else, such as `DR.read_file` on your own data files.
See [Paths are cart-relative](#paths-are-cart-relative).

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

Names come from the booted cart's own `sprites/` tree (indexed recursively at
boot, so `sprites/misc/star.png` is reachable as `:'misc/star'` and
`sprite(:star)`), plus anything registered through `self.assets`, plus the
console's starter art as a fallback.

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

### Levels (LDTK)

[LDTK](https://ldtk.io) is supported natively. Point the console at an `.ldtk`
export and it spawns the entities and hands you the collision rects:

```ruby
map = load_map 'maps/Level_0.ldtk'
spawn_level map                       # every entity, by kind
body = body entity: @ship, gravity: 0.4

def update
  body.vx = input.axis_x * 4
  body.jump 9 if input.pressed?(:accept) && body.grounded?
  body.update map.solids
end
```

Entities need no registration. The LDTK `__identifier` becomes the console
`kind`, and its fields become attributes:

```ruby
map.entities_of('Enemy').first
# { kind: :enemy, x: 64.0, y: 80.0, w: 16.0, h: 16.0,
#   health: 3,          # an Int arrives as an Integer, not "3"
#   label: 'boss',
#   home_point: { x: 96.0, y: 112.0 },   # a Point field becomes x/y
#   one_way: false }
```

Field identifiers are snake_cased, so LDTK's `MaxSpeed` becomes `:max_speed`.

| Layer type | Becomes |
|---|---|
| `Entities` | entities in `map.entities` |
| `IntGrid` | collision rects in `map.solids` (any non-zero cell) |
| `Tiles` / `AutoLayer` | tile records in `map.tiles` (data only, not yet drawn) |

Options: `level:` picks a level by identifier, `flip_y: false` keeps raw LDTK
coordinates, `one_way_value: 2` marks pass-through cells, and
`solid_entities: ['Platform']` turns chosen entities into solids instead.

Two things this handles that a naive loader gets wrong:

- **Coordinates.** LDTK is top-left with y growing *down*; the console is
  bottom-left with y growing *up*. Positions are flipped on load, so a platform
  near the top of the level ends up at a high `y`.
- **Point fields.** A Point stores `cx`/`cy` and has *no* `value` key at all.
  In mruby a missing key raises when chained into rather than returning nil, so
  every field is read by branching on `__type`.

### Bodies

`Console::Body` is a kinematic platformer body — deliberately not a physics
engine. There is no solver and no rigid bodies, because the games that want one
need gravity, a floor and a wall, and that is a state machine.

```ruby
b = body x: 64, y: 400, w: 16, h: 24, gravity: 0.4

b.grounded?        # standing on something right now
b.landed?          # true on exactly ONE frame, the landing itself
b.wall?            # touching a wall
b.ceiling?         # head hit something
b.wall_dir         # :left / :right, the side that stopped it
b.floor            # the solid being stood on (for riding a moving platform)
b.fall_distance    # how far it has fallen since leaving the ground
b.jump 12          # set upward velocity; check grounded? yourself

b.vx = input.axis_x * 4
b.update map.solids
```

`gravity:` is a positive magnitude that pulls *down*, even though DragonRuby's
bottom-left origin makes falling a negative `vy`.

Solids are `{ x:, y:, w:, h: }` plus an optional `one_way:` flag, and they are
static — moving platforms are left to the cart.

Three details do the real work:

- **Substepping.** A body falling for two seconds accumulates enough velocity to
  cross a platform in one frame, where a single-frame overlap test reports no
  collision and the body drops through the floor. Every move is split into steps
  of at most 8px and each is fully resolved.
- **Axis separation.** A wall clears `vx` but leaves `vy`, so the body slides
  down the wall instead of sticking to it.
- **Step-up.** `step_height: 16` lets the body walk over a low ledge instead of
  stopping dead at it. Off by default, because auto-stepping lets a cart walk up
  a wall it meant to be blocked by.

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
| `ldtk` | LDTK end to end: loads a real `.ldtk` from its own `maps/`, spawns its entities, runs a body on its solids |
| `selftest` | the console's own test suite, with its fixtures |

Each one owns the files it uses — `carts/arcade/sprites/`, `carts/ldtk/maps/`,
`carts/selftest/fixtures/` — which is what makes them independent. Screenshots
of each live in `shots/` (regenerate with `--shot`).

---

## Tests

```sh
./run-test
```

175 tests / 1435 assertions, executed **inside the real DragonRuby runtime** —
against the real renderer, the real output collections and the real mruby build,
not a stand-in. The suite covers geometry, strings, palettes, asset scoping and
cart isolation, the sprite index and procedural generation, drawing and
coordinate systems, tweens and easing, scenes, entities, animation, the camera,
widgets, input, cart selection and pinning, LDTK loading, platformer collision,
and the runtime wiring.

It prints a machine-readable summary:

```
CONSOLE_TEST_STATUS=PASS TESTS=175 ASSERTIONS=1435 FAILURES=0
```

`./smoke` additionally boots every cart headlessly and fails if any raises.

---

## Notes on mruby

DragonRuby embeds **mruby 3.0**, which is not Ruby. The console is written
against what mruby actually provides, and a few things are worth knowing because
they shaped the design:

- **No `Regexp`.** All string handling goes through `Console::Str`.
- **`/` is always float division.** `181 / 20` is `9.05`, not `9` as in CRuby.
  Any index or grid maths needs an explicit `.to_i`, or a level's tiles end up
  each at a slightly different position.
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