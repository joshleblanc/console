# AGENTS.md

The Cartridge Console: a fantasy-console library for [DragonRuby](https://dragonruby.org)
that turns a **cart** (one directory) into a running game. `README.md` is the
authoritative reference for the cart contract and the API; read the relevant
section before changing behaviour.

## Where this checkout lives

This repo is cloned **inside a DragonRuby install**, as a sibling of the engine
binaries:

```
<dragonruby install>/        e.g. C:\source\dragonruby
├── dragonruby(.exe)         the engine
├── dragonruby-publish(.exe) the packager
├── docs/                    engine docs (api/, guides/, samples/, static/docs.txt)
├── samples/                 official engine sample games
├── builds/                  publish-cart output (cart-staging/ and packages)
├── eula.txt, VERSION.txt
└── console/                 <- this repo
```

- **Engine docs and samples are one level up.** Use `../docs/` (e.g.
  `../docs/api/outputs.md`, `../docs/api/inputs.md`, or the single-file
  `../docs/static/docs.txt`) and `../samples/` when you need to know how a
  DragonRuby API behaves. Prefer them over memory or the web: they match the
  installed engine version (`../VERSION.txt`).
- **Every script in `bin/` assumes this layout.** They `cd` to the repo root
  and run `../dragonruby` / `../dragonruby-publish` (`.exe` on Windows), and
  `publish-cart` stages into `../builds/`. Do not move the repo out of the
  install, and do not "fix" those relative paths.
- Other sibling directories (`../mygame`, `../drecs`, etc.) are unrelated
  projects; don't modify them.

## Layout

- `app/main.rb` — entry point; `app/console/*.rb` — the library
  (`core.rb` holds `Console::API`, `version.rb` the version).
- `carts/<name>/` — one cart each, entry `app/main.rb`, defining a class named
  after the directory. A cart owns its `sprites/`, `sounds/`, `maps/`, `data/`.
- `carts/selftest/` — the test suite and its fixtures.
- `sprites/` — console starter art (fallback for carts without their own).
- `bin/` — scripts; each has a POSIX `sh` version and a `.bat` twin.
- `shots/`, `errors/`, `builds/`, `dragonstation.json` are git-ignored.
  Never commit `dragonstation.json` (it holds a live API key).

## Commands

Run from the repo root. On Windows use the `.bat` form (`bin\run.bat`).

```sh
./bin/run [cart] [--scene s] [--hud]   # boot a cart (bare name = carts/<name>)
./bin/run --list                       # list carts
./bin/new-cart <name> [--no-git]       # scaffold carts/<name>/ from a template
./bin/run-test                         # self test; passes iff it prints CONSOLE_TEST_STATUS=PASS
./bin/smoke [ticks]                    # boot every cart headlessly, fail if any raises
./bin/run hello --ticks 60 --shot shots/hello.png   # headless screenshot
```

After changing the library, run `run-test` **and** `smoke`. Tests execute inside
the real DragonRuby runtime, so there is no separate Ruby toolchain to install.
On a headless Linux box wrap commands in `xvfb-run -a`.

The `publish-*` and `update-library` scripts talk to packaging or a remote
site; only run them (even `--dry-run`) when asked.

## Conventions and gotchas

- **This is mruby 3.0, not CRuby.** No `Regexp` (use `Console::Str`); `/` is
  always float division (use `.to_i` for indices); see "Notes on mruby" in
  `README.md` for the rest.
- Helpers take exactly **one options hash** (mruby binds trailing `key: value`
  to the first optional param).
- Origin is bottom-left; widgets/draw calls accept `top:`.
- Use sprites with `path: :solid`, not `outputs.solids`.
- Cart paths are cart-relative; carts must live inside the console and should
  own their assets (`publish-cart` stages the cart directory alone).
- The console's test switch is `--selftest` (DragonRuby owns `--test`).
- When editing a `bin/` script, update its sh/`.bat` twin to match.
- When changing public API or behaviour, update `README.md` (and
  `assignments.md` if it references it), and add/adjust tests in
  `carts/selftest/`.
