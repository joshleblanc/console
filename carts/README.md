# Carts

One directory per cart. A cart is named after its directory, and its entry
file is `app/<name>.rb` — `carts/space/app/space.rb` defines `Space`.

```
carts/mygame/
├── app/mygame.rb       the cart: one class, named after this directory
├── sprites/            its own art, named for it and nothing else
├── sounds/             its own sounds and music
├── maps/               its own LDTK levels
└── data/               anything else it reads
```

Everything a cart references has to live inside it. A cart is staged on its own
when it is published, so a reference that resolves against the console root is a
file that will not be there — a visibly missing sprite rather than an invisible
one. The console's own `sprites/` is starter art for a cart that has no file of
its own, not a place to keep yours.

List what is here with `./bin/run --list`, boot one with `./bin/run <name>`, and
send one to a Dragonstation site with `./bin/publish-site <name>`.