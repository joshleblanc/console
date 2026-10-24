# Samples

The carts that ship with the console. Each one is a whole, working cart — its
own art, its own levels, its own tests — and each one exists to show a part of
the library being used for real.

| Cart | What it is for |
|---|---|
| `hello` | the smallest cart that uses most of the surface; read it top to bottom |
| `arcade` | a real game: scenes, waves, camera, tweens, pause |
| `widgets` | every widget, as a live reference |
| `ldtk` | level loading + a kinematic body |
| `selftest` | the suite — the best usage documentation in the repo |

Boot one with `./bin/run <name>` — a bare name is looked up in `carts/` first
and in `samples/` second, so the samples run without any path:

```
./bin/run hello
./bin/run samples/arcade --scene play
```

They are samples, not your work: they live in `samples/` so that the carts you
write in `carts/` are yours alone. Copy one to start from it rather than
editing it in place:

```
cp -R samples/hello carts/hello
```

`carts/` is ignored by this repository (except for a `.keep/` folder that keeps
the directory in the checkout), so your carts are versioned separately from the
console and from these samples. See `carts/.keep/README.md`.
