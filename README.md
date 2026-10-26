# The Cartridge Console

A fantasy console for [DragonRuby](https://dragonruby.org): a small, opinionated
library that turns a **cart** — one directory — into a running game.

```ruby
# carts/space/app/main.rb
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
./bin/run --cart space
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

./bin/run                  # boot the default cart
./bin/run samples/hello    # boot a cart by path
./bin/run hello            # ...or by name (shorthand for the gallery)
./bin/run --cart hello     # the explicit switch form
./bin/run --list           # what carts exist in the gallery
./bin/run --hud            # start with the debug overlay on

./bin/run-test             # run the self test (exits non-zero on failure)
./bin/smoke                # boot every cart headlessly and report failures
```

A cart is a **path to a cart directory**, and the gallery is read from two
places: `carts/`, which is yours, and `samples/`, which ships with the console.
Any directory inside the console works — `games/space`, `demos/space`,
`carts/space` — and a bare name is shorthand for the gallery:

```sh
./bin/run games/space          # a cart that does not live in carts/
```

`carts/` is looked at first, so a cart of yours shadows a sample of the same
name. Scaffold a new cart from the template:

```sh
./bin/new-cart mygame
```

It also runs `git init` inside the cart with an initial commit — `carts/` is
yours to version separately, so each cart starts life as its own repository.
Pass `--no-git` to skip that.

...or copy a sample to start from it rather than editing it where it lives:

```sh
cp -R samples/hello carts/hello
```

> **`carts/` is yours.** This repository ignores everything under it except a
> `.keep/` folder, so the carts you write are never part of the console's
> history — source-control them separately, in a repository of your own. See
> `carts/.keep/README.md`.

The cart's name is the last segment of that path, and it is also the module the
cart has to define, so `games/space/app/main.rb` defines `Space`.

> A cart has to sit **inside** the console. DragonRuby resolves every file
> against the game directory and refuses to stat a path that escapes it, so
> `../elsewhere` and an absolute path both fail. The console says so rather than
> implying a typo.

Selection order is the cart argument, then `--cart`, then `$CART`, then the
default. A *published* build instead pins one cart, which outranks all of them —
see [Publishing a single cart](#publishing-a-single-cart). To debug one scene of a
game without playing through the front door:

```sh
./bin/run samples/arcade --scene play
```

### Switches

| Switch | Effect |
|---|---|
| `--cart <name\|path>` | which cart to boot |
| `--list` | print the gallery's carts and exit |
| `--selftest` | run the self test, print a report, exit |
| `--scene <name>` | jump straight into a named scene |
| `--hud` | start with the debug overlay on |
| `--ticks <n>` | quit after n frames (headless smoke runs) |
| `--shot <path>` | write a PNG of the last frames, then quit |

`--list` covers the gallery — `carts/` and `samples/`; a cart kept elsewhere is
still reachable by path, it just is not what the listing shows.

On a headless machine, wrap the console in `xvfb-run -a`.

---

## Dragonstation: installing and publishing

Dragonstation is a site where carts run: upload a cart directory and it plays
in the browser, against a copy of this library. Two scripts close the loop in
this direction.

**Installing the console.** The site serves the console it runs as a plain ZIP,
with no login, because it already hands every byte of it to any browser playing a
cart:

```sh
# a fresh console
curl -O http://localhost:3000/console/library.zip
unzip library.zip -d console

# ...or refresh this one
./bin/update-library --site=http://localhost:3000
```

The download is the whole console -- this `app/`, this `bin/`, the starter art,
the metadata, the sample carts, and a `carts/` directory to put a cart in -- not
just the library, so it unpacks into a console that boots. It compares versions
and does nothing unless the site is serving something newer than the
`MAJOR/MINOR/PATCH` in `app/console/version.rb`. Everything is unpacked to a
scratch directory and verified before it is moved into place, so a truncated
download cannot leave this console with half a library.

The ZIP carries Unix modes, so `unzip` gives you runnable scripts. A tool that
ignores them (`python3 -m zipfile`) will not, and `chmod +x bin/*` once fixes
that.

**Publishing a cart.** With the library downloaded from the site signed in, the
same download carries a file called `dragonstation.json`:

```json
{ "api_key": "ds_...", "publish_url": "https://.../api/carts", "site_url": "https://..." }
```

That file is this console's credential, and `./bin/publish-site` spends it:

```sh
./bin/publish-site --list            # what could be sent
./bin/publish-site arcade            # send samples/arcade
./bin/publish-site arcade --dry-run  # build it and check the key, send nothing
```

The cart arrives on the site as a **draft** under your account. Nothing goes
public because a script ran — you play it there, then publish it from its page.
Everything the site's upload form refuses, this refuses too, and says why:
traversal, symlinks, expansion bombs, and art a cart names but does not own.
A cart's `.git` is never part of the upload — a cart may be its own repository,
and its history stays home.

### Releasing a new console version

Administrators only. The same install the site's upload screen performs, driven
from here:

```sh
./bin/publish-console --dry-run   # build the archive, send nothing
./bin/publish-console             # install console 0.2.0 as a new version
```

Bump `MAJOR`/`MINOR`/`PATCH` in `app/console/version.rb` first. The site reads
the version from that same file and refuses one it already has, because a
cartridge pinned to 0.1.0 has to keep running against 0.1.0 forever.

#### The first version on a site

A site with nothing installed cannot run this script, and that is a real
deadlock rather than a missing step. `dragonstation.json` arrives only inside
the console bundle the site serves, and the site serves a bundle only once it
has a console version to build one from — so the tool that installs the first
version is the one tool that cannot reach the site yet.

`--pack-only` breaks it. It builds the same archive and needs no key at all:

```sh
./bin/publish-console --pack-only   # leaves the ZIP in builds/, sends nothing
```

Upload that ZIP at `/admin/console_versions/new`, make the version the default,
and downloads start working — after which `dragonstation.json` arrives in your
next bundle and `./bin/publish-console` behaves normally.

**A version is a console, not a checkout.** The archive carries the library,
the entry point, every script, the starter art, the sample carts and a `carts/`
directory with a README in it -- and none of this machine: no `.git`, no
`builds/`, no `shots/`, no `errors/last.txt`, no carts of your own, and not the
publishing key sitting in this directory. The script refuses to send an archive
that contains the key.

The file itself is only in an administrator's download from the site. The
server checks the key on every request anyway, so this is a convenience rather
than a permission.

Two things worth knowing before you rely on it:

- **`dragonstation.json` is gitignored.** It holds a live key. Do not commit it.
- **A key is replaced every time you download your bundle.** A console unpacked
  a while ago can hold one the site has retired; `./bin/publish-site` then answers
  with the fix rather than a bare error. Download the bundle again and unpack it
  over this directory.

---

## On Windows

Every shell script has a batch equivalent beside it, doing the same thing:

| Shell | Windows |
|---|---|
| `./bin/run [cart]` | `bin\run.bat [cart]` |
| `./bin/run-test` | `bin\run-test.bat` |
| `./bin/smoke [n]` | `bin\smoke.bat [n]` |
| `./bin/new-cart <name>` | `bin\new-cart.bat <name>` |
| `./bin/publish-cart` | `bin\publish-cart.bat` |
| `./bin/update-library` | `bin\update-library.bat` |
| `./bin/publish-site` | `bin\publish-site.bat` |
| `./bin/publish-console` | `bin\publish-console.bat` |

```bat
run.bat                             boot the default cart
run.bat samples\hello               boot a cart by path
run.bat hello                       ...or by name
run.bat --cart samples\arcade       the explicit switch form
run.bat --list                      list the gallery

run-test.bat                        the self test, non-zero on failure
smoke.bat                           boot every cart headlessly
smoke.bat 600                       ...for 600 frames each

new-cart.bat mygame                 scaffold a new cart

publish-cart.bat --list             list publishable carts
publish-cart.bat arcade             package arcade for windows-amd64
publish-cart.bat arcade --dry-run   stage + verify, package nothing
publish-cart.bat arcade --publish   package arcade and upload it to itch.io
```

They expect the DragonRuby binaries in the parent directory, as on every other
platform, and `publish-cart.bat` defaults `--platforms` to `windows-amd64`.

The library, the cart contract and the runtime are entirely platform-neutral —
only these four scripts differ. Two differences worth knowing:

- **`publish-cart.bat` checks assets by booting.** `./bin/publish-cart` greps the
  cart's source for quoted asset paths. Parsing quotes in batch is fragile
  enough that it would either skip the check or abort a good build, so the batch
  version boots the staged directory for 60 frames and looks for the console's
  own missing-asset warnings. That is stricter — it catches exactly the assets
  the cart fails to load — but it only sees assets used at runtime, and it opens
  a window. If the staged build cannot run at all, it says so loudly rather than
  passing quietly.
- **Carts must have CRLF endings.** A batch file with LF endings mangles labels
  and parenthesised blocks in ways that look like logic bugs.
  [`.gitattributes`](.gitattributes) pins `*.bat` to CRLF and the shell scripts
  to LF.

> **The batch files were written by hand and reviewed, not executed.** They were
> checked statically — labels, calls and control flow — on a machine that cannot
> run `cmd.exe`. `publish-cart.bat` has since been run and fixed; the others
> should still be treated as a first run.
>
> Batch has a few sharp edges the shell scripts do not, and the differences
> are handled inside the `.bat` files so the commands behave the same on both:
> arguments are split on `=` and `,` before a batch file ever sees them
> (`--platforms=html5,linux-amd64` arrives as three arguments), `goto :eof`
> does not carry an exit status, and `cmd`'s `copy` cannot follow a forward
> slash in the source path.

---

## Publishing a single cart

`dragonruby-publish` packages a whole game directory, and this directory holds
*every* cart under `carts/` and `samples/`. Pointed at the console, it would ship
the selftest, the widgets gallery and the arcade cart all inside one build.

So publish through `./bin/publish-cart`, which stages a throwaway directory first:

```sh
./bin/publish-cart --list                  # carts, with the titles that will publish
./bin/publish-cart arcade                  # package arcade for linux-amd64
./bin/publish-cart arcade --dry-run        # stage + verify, package nothing
./bin/publish-cart arcade --platforms=html5,linux-amd64
```

It stages `builds/cart-staging/<cart>/` containing the console library, the
cart directory (code *and* the sprites, sounds, maps and data it owns),
metadata derived from the cart's `TITLE`, and an entry point that **pins** the
cart — then packages that directory. A cart's `.git` never reaches the staging
directory. Artifacts land in `../builds/`.

### Metadata

`metadata/game_metadata.txt` is the one file a cart genuinely cannot own: the
engine reads it from the **game root** (the path is hardcoded in DragonRuby), so
every cart shares it while you develop. Running `--cart arcade` in a checkout
therefore still identifies as `Console` — that is DragonRuby, not the console.

Publishing resolves it per cart. A cart that ships its own
`metadata/game_metadata.txt` uses that verbatim — its own identity,
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

## Publishing to itch.io

`publish-cart` packages by default. Add `--publish` and the engine uploads the
result as well:

```sh
./bin/publish-cart trijam-395 --publish
```

That upload is DragonRuby's own, not a reimplementation. `dragonruby-publish`
keeps its itch.io butler up to date, reads the itch.io username and project
slug out of the staged metadata, tags the build with the version, and maps
each platform to its itch.io channel (`html5`, `windows-amd64`, `linux-amd64`,
`macos`, …). `publish-cart` only chooses whether to let it.

**The itch project slug is the cart's name.** `publish-cart` sets `gameid` to
the cart name, and the engine uses `gameid` as the project slug and `devid` as
the username — so a cart called `trijam-395` publishes to
`horizonshadow/triam-395`, and `devid` is already `horizonshadow` in the
console's metadata. Create the page on itch.io first (for a jam entry, create
it from the jam's own page so it links to the jam), with **Project URL** set to
the cart name.

To publish under a different slug or account, a cart can ship its own
`metadata/itchio_metadata.txt`, which the staged build carries verbatim:

```
itchio.publish=true
itchio.username=horizonshadow
itchio.gameid=trijam-395
```

If you would rather upload by hand, `publish-cart` on its own leaves the
builds in `../builds/`, which itch.io's web uploader will take. The html5
build is the one to upload as "This file will be played in the browser".

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
├── carts/                   your gallery: one directory per cart of yours
│   └── .keep/                the only part of it this repository tracks
│       └── README.md         what a cart is, and that the directory is yours
├── samples/                 the sample carts that ship with the console
│   └── space/
│       ├── app/main.rb       the cart, plus any code files beside it
│       ├── sprites/          its own art
│       ├── sounds/           its own sounds and music
│       ├── maps/             its own LDTK levels
│       └── data/             anything else it reads
├── sprites/                 console starter art: the fallback when a cart has
│                            no file of its own
├── bin/                     every script, and their .bat equivalents
│   ├── run                  boot a cart
│   ├── run-test             the self test
│   ├── smoke                boot every cart headlessly
│   ├── new-cart             scaffold a new cart
│   ├── publish-cart         package exactly one cart for desktop
│   ├── publish-site         send a cart to a Dragonstation site
│   ├── publish-console      release a new console version (admin)
│   └── update-library       refresh the library from one
├── shots/                   screenshots written by --shot
├── errors/                  the last crash's output, and what to do about it
└── metadata/game_metadata.txt
```

---

## The cart contract

A cart is a directory. Its entry file is `app/main.rb`, and it defines a class
(or a module) named after the directory. Implement whichever hooks you need —
they are all optional.

```ruby
# carts/mygame/app/main.rb
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

### Declaring a sprite that is a tile in a sheet

A sprite declaration can also name **one tile inside a sheet**. The crop travels
with the name, so everything that draws `:hero` draws that tile — `draw_sprite`,
`draw.sprite`, and entities spawned with `sprite: :hero`:

```ruby
def self.assets
  { sprites: {
      # A grid: tiles are numbered left to right, top to bottom, and tile 0 is
      # the TOP-LEFT tile -- the way a tileset is drawn.
      hero: { sheet: 'sprites/hero.png', index: 3,
              tile_w: 16, tile_h: 16, cols: 8 },

      # Or an explicit rectangle in the sheet, if the sheet is not a grid.
      crate: { sheet: 'sprites/props.png',
               tile_x: 48, tile_y: 0, tile_w: 16, tile_h: 16 } } }
end
```

`auto_sprite` knows a declared tile is a tile:

- **the sheet exists** — the real art is used, cropped to the tile;
- **the sheet is missing** — a placeholder the size of the *tile* is generated,
  so the cart still runs, and the art is still one tile big when it arrives.

```ruby
def setup
  auto_sprite :hero          # the tile, cropped, or a tile-sized placeholder
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
publishing, because `./bin/publish-cart` stages the cart directory alone, so
anything borrowed would simply be missing from the build.

### More than one file

The entry file is required first and the rest of `app/*.rb` follows, so a cart
can be split up with no wiring:

```
carts/space/app/main.rb       # the cart
carts/space/app/entities.rb   # required automatically
```

Sub-directories are the cart's own to require
(`require 'carts/space/app/boss/boss'`). Only the booted cart's files are ever
required, so a cart broken mid-edit cannot stop the console from starting.

`app/<name>.rb` is still accepted as an entry file name, so a cart written that
way keeps working — the loader prefers `app/main.rb` and falls back to it.

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

A scene may implement `enter`, `update`, `render` and `leave` (or be a Hash of
those hooks as lambdas). Scene changes are
committed at the end of the frame, so calling `goto` from inside `update` never
leaves the frame half-applied. `goto` and `unwind` run `leave` on every scene
they remove, including one paused under an overlay.

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

**Sprite sheets.** Three helpers crop one tile out of a sheet, and each draws
it at the tile's own size unless `w:`/`h:` say otherwise:

```ruby
# A grid-packed sheet, addressed by tile index (left to right, top to bottom).
draw.sprite_tile path: 'tiles.png', index: 7,
                 tile_w: 16, tile_h: 16, cols: 8

# A horizontal strip, addressed by frame index.
draw.sprite_sheet_frame path: 'explosion.png', frame_w: 32, frame_h: 32,
                         frame_index: 1

# Any crop, by absolute source coordinates (bottom-left origin).
draw.sprite_frame path: 'tiles.png', source: { x: 32, y: 0, w: 16, h: 16 }
```

`source:` crops use DragonRuby's bottom-left origin, like every other
coordinate in the console. `sprite_tile` reads the grid from the *top* left,
the way a tileset is drawn, because that is how tile 0 is numbered.

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
menu and `:accept` activates it; `:cancel` drops a button's or slider's focus.
A menu lists its items top-down (item 0 on top), and its `y:`/`top:` place the
bottom/top edge of the whole list.

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
`Console::Input::ACTIONS`. On the keyboard `:action_1`/`:action_2` are Q/E
(kept clear of WASD, which already drives the directions); on a pad they are
L1/R1, and `:action_3`/`:action_4` are L2/R2.

### Entities

Entities are plain Hashes with a unique `id`, a `kind` tag and a rect — which
means they are already valid DragonRuby primitives.

```ruby
ship = spawn :ship, kind: :hero, x: 100, y: 100, w: 24, h: 24, sprite: :hero

each_entity(:enemy) { |e| move e, vx: e[:vx], vy: e[:vy] }
each_entity(:bullet) { |b| despawn b if b[:y] > 900 }   # despawning mid-loop is safe
toward ship, target, 4   # aim ship[:vx]/[:vy] at target, 4px per frame
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
animate entity, :hit, repeat: false, on_finish: :idle   # one-shot, then idle
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

`auto_sprite` makes a whole texture: it has no sheet or tile selector, and it
never overwrites a real file. A name that is *declared* as a tile in a sheet is
the exception — see
[Declaring a sprite that is a tile in a sheet](#declaring-a-sprite-that-is-a-tile-in-a-sheet).
To pull a tile out of a sheet at draw time instead, use `draw.sprite_tile` or
`draw.sprite_sheet_frame` — see [Drawing](#drawing).

Names come from the booted cart's own `sprites/` tree (indexed recursively at
boot, so `sprites/misc/star.png` is reachable as `:'misc/star'` and
`sprite(:star)`), plus anything registered through `self.assets`, plus the
console's starter art as a fallback.

### Audio

```ruby
sfx :shoot
sfx :hit, pitch: 0.8, gain: 0.5
music :title
music_gain 0.4            # master volume: the playing track and every sfx
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

A followed entity is tracked every frame without calling `camera.update`.
`camera.bounds` keeps the whole view (at the current zoom) inside the world, and
centres a world smaller than the screen. `camera.visible_rect` is the world
rect on screen, and the camera can be tweened like a hash
(`tween camera, :zoom, to: 2.0, in: 20`).

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
Both the 1.x payload key (`value`) and the current one (`__value`) are read, so
old and new exports load the same way.

| Layer type | Becomes |
|---|---|
| `Entities` | entities in `map.entities` — unless they declare themselves solid, in which case a collision rect in `map.solids` instead |
| `IntGrid` | collision rects in `map.solids` (any non-zero cell) |
| `Tiles` / `AutoLayer` | tile records in `map.tiles` (data only, not yet drawn) |

An entity becomes collision when the **map** says so, not when the cart lists it,
so a level never has to be mirrored in console code:

| Marker | Where it is set |
|---|---|
| truthy `Solid` bool field | on the entity, or defaulted once on the entity *type* in LDTK |
| truthy `OneWay` bool field | same — a pass-through platform is still a platform, so one-way implies solid |
| `solid_entities: ['Platform']` | on the `load_map` call, naming LDTK identifiers outright |

LDTK bakes an entity type's field defaults into every placed copy, so ticking
`Solid` once on a `Platform` type in the editor marks every `Platform` in the
level. Both field markers and `solid_entities:` also compose: the option is the
escape hatch for an entity type that carries neither field.

Options: `level:` picks a level by identifier, `flip_y: false` keeps raw LDTK
coordinates, and `one_way_value: 2` marks pass-through cells.

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
static — moving platforms are left to the cart. A one-way solid only catches a
body falling onto it from above; it never blocks rising or sideways motion.

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

after(30) { spawn Enemy, x: 100, y: 100 }
every(60, immediate: true) { next_wave }
```

Easings: `:linear :in :out :in_out :smooth :elastic :bounce`. `loops: n` replays
the tween n times; add `yoyo: true` to alternate direction instead.

Timers and tweens run on the console's own clock, which stops while a
`push_scene` overlay is up: a pause freezes them rather than letting them
fire the moment play resumes.

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

## Samples included

These live in `samples/`, and are the carts the console ships with.

| Cart | What it shows |
|---|---|
| `hello` | the smallest interesting cart; no assets, generated textures |
| `arcade` | a playable MVP: scenes, waves, shooting, camera, shake, tweens, pause overlay, game over |
| `widgets` | every UI widget, laid out as a live reference |
| `ldtk` | LDTK end to end: loads a real `.ldtk` from its own `maps/`, spawns its entities, runs a body on its solids |
| `selftest` | the console's own test suite, with its fixtures |

Each one owns the files it uses — `samples/arcade/sprites/`, `samples/ldtk/maps/`,
`samples/selftest/fixtures/` — which is what makes them independent. Screenshots
of each live in `shots/` (regenerate with `--shot`).

They are samples, not your work: copy one into `carts/` to start from it
rather than editing it where it lives.

---

## Tests

```sh
./bin/run-test
```

248 tests / 1677 assertions, executed **inside the real DragonRuby runtime** —
against the real renderer, the real output collections and the real mruby build,
not a stand-in. The suite covers geometry, strings, palettes, asset scoping and
cart isolation, the sprite index and procedural generation, drawing and
coordinate systems, tweens and easing, scenes, entities, animation, the camera,
widgets, input, cart selection and pinning, LDTK loading, platformer collision,
and the runtime wiring.

It prints a machine-readable summary:

```
CONSOLE_TEST_STATUS=PASS TESTS=248 ASSERTIONS=1677 FAILURES=0
```

`./bin/smoke` additionally boots every cart headlessly and fails if any raises.
On Windows `dragonruby.exe` is a GUI program whose stdout cannot be captured, so
`run-test.bat` and `smoke.bat` read the engine's `..\logs\console.log` instead.

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