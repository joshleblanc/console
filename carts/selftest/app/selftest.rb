# Cart: selftest
#
# The console's own test suite. Run it with:
#
#   ./run-test
#
# Everything is asserted against the live DragonRuby runtime, so these are not
# mocked unit tests: they exercise the real output collections, the real
# renderer and the real mruby build.
TITLE = 'self test'

class GeomSuite
  include Console::Test

  test 'rect builds a rect' do
    r = Console::Geom.rect 1, 2, 3, 4
    assert_equal 1, r[:x]
    assert_equal 4, r[:h]
  end

  test 'center works on a plain hash (no engine center key)' do
    r = { x: 0, y: 0, w: 10, h: 20 }
    assert_equal 5, Console::Geom.center(r).x
    assert_equal 10, Console::Geom.center(r).y
  end

  test 'center honours anchors' do
    r = { x: 10, y: 10, w: 10, h: 10, anchor_x: 0.5, anchor_y: 0.5 }
    c = Console::Geom.center r
    assert_almost_equal 15, c.x
    assert_almost_equal 15, c.y
  end

  test 'inset shrinks all sides' do
    r = Console::Geom.inset({ x: 0, y: 0, w: 100, h: 100 }, 10)
    assert_equal 10, r[:x]
    assert_equal 80, r[:w]
    assert_equal 80, r[:h]
  end

  test 'columns splits evenly and fits inside' do
    cells = Console::Geom.columns({ x: 0, y: 0, w: 100, h: 10 }, 4)
    assert_equal 4, cells.size
    assert_equal 25, cells[0][:w]
    assert_equal 75, cells[3][:x]
  end

  test 'columns accounts for gaps' do
    cells = Console::Geom.columns({ x: 0, y: 0, w: 100, h: 10 }, 3, 5)
    # 100 - 2*5 gap = 90 / 3 = 30
    assert_equal 30, cells[0][:w]
    assert_equal 35, cells[1][:x]
    assert_equal 70, cells[2][:x]
  end

  test 'place positions by fraction and anchor' do
    base = { x: 0, y: 0, w: 200, h: 100 }
    r = Console::Geom.place(base, x: 0.5, y: 1.0, w: 20, h: 20,
                             anchor_x: 0.5, anchor_y: 1.0)
    assert_equal 90, r[:x]
    assert_equal 80, r[:y]
  end

  test 'contains? is half-open and excludes the far edge' do
    r = { x: 0, y: 0, w: 10, h: 10 }
    assert Console::Geom.contains?(r, 0, 0)
    assert Console::Geom.contains?(r, 9.99, 9.99)
    refute Console::Geom.contains?(r, 10, 5)
    refute Console::Geom.contains?(r, -1, 5)
  end

  test 'clamp_inside keeps a rect within bounds' do
    bounds = { x: 0, y: 0, w: 100, h: 100 }
    r = Console::Geom.clamp_inside({ x: 90, y: -20, w: 50, h: 20 }, bounds)
    assert_equal 50, r[:x]
    assert_equal 0, r[:y]
  end

  test 'contain letterboxes preserving aspect ratio' do
    inner = { x: 0, y: 0, w: 200, h: 100 }
    outer = { x: 0, y: 0, w: 100, h: 100 }
    r = Console::Geom.contain inner, outer
    assert_equal 100, r[:w]
    assert_equal 50, r[:h]
    assert_equal 25, r[:y]
  end
end

class StrSuite
  include Console::Test

  test 'chop removes a suffix' do
    assert_equal 'hello', Console::Str.chop('hello.rb', '.rb')
    assert_equal 'hello', Console::Str.chop('hello', '.rb')
  end

  test 'digits? replaces a numeric regex' do
    assert Console::Str.digits?('007')
    refute Console::Str.digits?('7a')
    refute Console::Str.digits?('')
  end

  test 'camel and snake round trip' do
    assert_equal 'HelloWorld', Console::Str.camel('hello-world')
    assert_equal 'hello_world', Console::Str.snake('HelloWorld')
  end

  test 'quoted_value_after extracts a constant' do
    src = "TITLE = 'Hello World'\nfoo"
    assert_equal 'Hello World', Console::Str.quoted_value_after(src, 'TITLE')
    src2 = 'TITLE = "Double"'
    assert_equal 'Double', Console::Str.quoted_value_after(src2, 'TITLE')
    assert_nil Console::Str.quoted_value_after('nothing here', 'TITLE')
  end

  # A cart's directory is its path, and its path is its name, so these two are
  # load-bearing rather than conveniences. Hand-rolled because mruby has no
  # Regexp and no dependable Range-indexed String#[].
  test 'chomp_slash removes trailing slashes only' do
    assert_equal 'carts/space', Console::Str.chomp_slash('carts/space/')
    assert_equal 'carts/space', Console::Str.chomp_slash('carts/space')
    assert_equal 'carts//space', Console::Str.chomp_slash('carts//space')
    assert_equal '/', Console::Str.chomp_slash('/')
  end

  test 'basename takes the last path segment' do
    assert_equal 'space', Console::Str.basename('carts/space')
    assert_equal 'space', Console::Str.basename('carts/space/')
    assert_equal 'one', Console::Str.basename('a/b/c/one')
    assert_equal 'space', Console::Str.basename('space')
    assert_equal 'b', Console::Str.basename('/a/b')
    assert_equal '', Console::Str.basename('')
  end
end

class PaletteSuite
  include Console::Test

  test 'named colors resolve' do
    h = Console::Palette.to_hash :accent
    assert_equal 96, h[:r]
    assert_equal 200, h[:g]
  end

  test 'arrays pass through' do
    h = Console::Palette.to_hash [1, 2, 3]
    assert_equal 1, h[:r]
    assert_equal 3, h[:b]
  end

  test 'alpha overrides and 4-element arrays carry alpha' do
    assert_equal 128, Console::Palette.to_hash(:white, 128)[:a]
    assert_equal 64, Console::Palette.to_hash([0, 0, 0, 64])[:a]
  end

  test 'unknown symbols fall back to white rather than crashing' do
    assert_equal 255, Console::Palette.to_hash(:not_a_color)[:r]
  end
end

# Asset scoping is what keeps two carts from colliding, so it is tested on its
# own instead of only as a side effect of the sprite index.
class AssetsSuite
  include Console::Test

  SHIPPED = %w[arcade hello ldtk selftest widgets]

  # Every test here moves the global asset scope. Put it back the way the boot
  # left it -- and rebuild the index to match -- so no later suite can inherit
  # somebody else's cart.
  def scoped(cart_root)
    before = Console::Assets.root
    Console::Assets.boot cart_root
    begin
      yield
    ensure
      Console::Assets.boot before
      Console::Sprites.index!
    end
  end

  test 'a booted cart knows its own directory' do
    scoped 'carts/arcade' do
      assert_equal 'carts/arcade', Console.assets_root
      assert Console::Assets.scoped?
    end
  end

  test 'paths are cart-relative' do
    scoped 'carts/ldtk' do
      assert_equal 'carts/ldtk/maps/Level_0.ldtk',
                   Console.asset('maps/Level_0.ldtk')
    end
  end

  test 'resolving twice does not nest the path' do
    # Paths travel through several layers (a cart alias, then draw.sprite), so
    # resolution has to be idempotent or a path ends up doubled up.
    scoped 'carts/ldtk' do
      once = Console.asset 'maps/Level_0.ldtk'
      assert_equal once, Console.asset(once)
    end
  end

  test 'a missing asset points at the copy the cart should own' do
    # Naming the cart's own path means the "not found" warning tells the author
    # where to put the file instead of pointing at a shared location.
    scoped 'carts/hello' do
      assert_equal 'carts/hello/sprites/nope.png',
                   Console.asset('sprites/nope.png')
    end
  end

  # True when this checkout still has console-root art to borrow. A published
  # build stages the cart alone, so there is no root to borrow from and the
  # expectations below become the cart-local ones instead. Asserting the dev
  # checkout unconditionally would make these tests fail in a shipped build.
  def console_root_art?(path)
    !DR.stat_file(path).nil?
  end

  test 'an asset only at the console root resolves, and is reported' do
    scoped 'carts/hello' do
      if console_root_art? 'sprites/dragon-0.png'
        assert_equal 'sprites/dragon-0.png', Console.asset('sprites/dragon-0.png')
        assert Console::Assets.shared?('sprites/dragon-0.png')
        assert_includes Console.shared_assets, 'sprites/dragon-0.png'
      else
        assert_equal 'carts/hello/sprites/dragon-0.png',
                     Console.asset('sprites/dragon-0.png')
      end
    end
  end

  test 'non-strings pass through untouched' do
    scoped 'carts/hello' do
      assert_equal :star, Console.asset(:star)
      assert_equal 'http://example.com/a.png',
                   Console.asset('http://example.com/a.png')
    end
  end

  # The two properties that make carts independent: a cart's file shadows the
  # console's copy of the same name, and a cart cannot see another cart.
  test 'the cart copy wins over an identically named console file' do
    scoped 'carts/selftest' do
      assert_equal 'carts/selftest/sprites/star.png',
                   Console.asset('sprites/star.png')
    end
  end

  test 'a cart cannot reach another cart assets' do
    scoped 'carts/selftest' do
      Console::Sprites.index!
      refute_equal 'carts/arcade/sprites/hero/idle/0.png',
                   Console::Sprites.path('hero/idle/0')
    end
  end

  test 'a cart still gets console starter art it does not own' do
    scoped 'carts/arcade' do
      Console::Sprites.index!
      assert_equal 'carts/arcade/sprites/hero/idle/0.png',
                   Console::Sprites.path('hero/idle/0')
      # The second half needs a console root to fall back to; in a staged
      # build the cart simply does not know the name, which is also correct.
      if console_root_art? 'sprites/dragon-0.png'
        assert_equal 'sprites/dragon-0.png', Console::Sprites.path('dragon-0')
      end
    end
  end

  test 'every cart ships an entry file the loader can require' do
    loader = Console::CartLoader.new $args
    found = loader.available
    SHIPPED.each do |name|
      assert_includes found, name
      assert DR.stat_file(loader.cart_entry("carts/#{name}")),
             "cart #{name} has no entry file at #{loader.cart_entry("carts/#{name}")}"
    end
    # A cart is a directory, never a loose .rb file.
    refute_includes found, 'selftest.rb'
  end

  # A cart is named by a path, and a bare name is shorthand for the gallery.
  # Both routes have to reach the same directory, or ./run carts/x and ./run x
  # would quietly boot different things.
  test 'a bare name resolves into the default gallery' do
    loader = Console::CartLoader.new $args
    assert_equal 'carts/arcade', loader.cart_dir('arcade')
    assert_equal 'carts/selftest', loader.cart_dir('selftest')
  end

  test 'a path is taken as given, whatever it points at' do
    loader = Console::CartLoader.new $args
    assert_equal 'games/space', loader.cart_dir('games/space')
    assert_equal 'demos/deep/one', loader.cart_dir('demos/deep/one')
  end

  test 'a trailing slash does not change which cart is meant' do
    loader = Console::CartLoader.new $args
    assert_equal 'carts/arcade', loader.cart_dir('carts/arcade/')
    assert_equal 'games/space', loader.cart_dir('games/space/')
  end

  test "a cart's name is the last segment of its directory" do
    loader = Console::CartLoader.new $args
    assert_equal 'arcade', loader.cart_name('carts/arcade')
    assert_equal 'space', loader.cart_name('games/space')
    assert_equal 'one', loader.cart_name('a/b/c/one')
    assert_equal 'space', loader.cart_name('games/space/')
  end

  test 'the entry file is app/main.rb, falling back to the cart name' do
    loader = Console::CartLoader.new $args
    # The shipped carts use app/<name>.rb, which still resolves.
    assert_equal 'carts/arcade/app/arcade.rb', loader.cart_entry('carts/arcade')
    # A directory with no main.rb and no name match is not a cart at all.
    assert_equal false, loader.cart?('carts/nope')
    assert_equal false, loader.cart?('carts')
  end
end

# Every path below is cart-relative in the source and cart-scoped in the
# result: the selftest cart owns these files, and the console rewrites them to
# real paths under carts/selftest. The console root holds a copy of star.png
# too, which is what makes these tests prove isolation rather than just
# resolution.
class SpritesSuite
  include Console::Test

  test 'the cart copy of an asset wins over the console root' do
    Console::Sprites.index!
    assert_equal 'carts/selftest/sprites/star.png', Console::Sprites.path(:star)
  end

  test 'nested assets resolve by relative key' do
    Console::Sprites.index!
    assert_equal 'carts/selftest/sprites/misc/star.png',
                 Console::Sprites.path('misc/star')
  end

  test 'a cart-relative path resolves inside the cart' do
    assert_equal 'carts/selftest/sprites/blue.png',
                 Console::Sprites.path('sprites/blue.png')
  end

  test 'missing sprites fall back to solid and are reported' do
    before = Console::Sprites.missing_names.size
    assert_equal :solid, Console::Sprites.path(:definitely_not_here)
    assert Console::Sprites.missing_names.size > before
    assert_includes Console::Sprites.missing_names, 'definitely_not_here'
  end

  test 'generated textures become renderable symbols' do
    name = 'test_generated_block'
    result = Console::Sprites.generate $args, name, 8, 8, :accent, :checker
    assert_equal name.to_sym, result
    assert Console::Sprites.exists?(name)
    size = Console::Sprites.size name
    assert_equal 8, size[0]
    assert_equal 8, size[1]
  end

  test 'checker alternates pixels' do
    name = 'test_generated_checker2'
    Console::Sprites.generate $args, name, 4, 4, [255, 255, 255], :checker
    pa = $args.pixel_array(name.to_sym)
    a = pa.pixels[0]
    b = pa.pixels[1]
    refute_equal a, b, 'a checkerboard needs two distinct pixel values'
  end

  test 'stripes band horizontally' do
    name = 'test_generated_stripes'
    Console::Sprites.generate $args, name, 4, 8, [255, 255, 255], :stripes
    pa = $args.pixel_array(name.to_sym)
    top_row = (pa.height - 1) * pa.width
    bot_row = 0
    refute_equal pa.pixels[bot_row], pa.pixels[top_row],
                 'the top and bottom of an 8px stripe run should differ'
  end

  test 'frame pattern leaves transparent corners' do
    name = 'test_generated_frame'
    Console::Sprites.generate $args, name, 6, 6, [255, 255, 255], :frame
    pa = $args.pixel_array(name.to_sym)
    corner = pa.pixels[((pa.height - 1 - 0) * pa.width) + 0]
    refute_equal 0, corner & 0xFF000000, 'the corner should be opaque'
  end

  test 'procedural circle clears its corners' do
    name = 'test_generated_circle'
    Console::Sprites.generate $args, name, 16, 16, :white, :circle
    pa = $args.pixel_array(name.to_sym)
    row = pa.height - 1 - 1
    assert_equal 0, pa.pixels[(row * pa.width) + 1] & 0xFF000000
  end

  test 'abgr packing puts red in the low byte' do
    packed = Console::Sprites.rgba [255, 0, 0, 128]
    assert_equal 0xFF0000FF, packed
  end
end

class DrawSuite
  include Console::Test

  def outputs
    $args.outputs
  end

  def reset
    outputs.sprites.clear
    outputs.labels.clear
    outputs.borders.clear
    outputs.lines.clear
  end

  test 'rect pushes a :solid sprite with the resolved color' do
    reset
    Console.draw.rect x: 10, y: 20, w: 30, h: 40, color: :accent
    prim = outputs.sprites.last
    assert_equal 10, prim[:x]
    assert_equal 40, prim[:h]
    assert_equal 96, prim[:r]
    assert_equal 255, prim[:a] || 255
  end

  test 'rect returns the rect it drew' do
    reset
    r = Console.draw.rect x: 1, y: 2, w: 3, h: 4
    assert_equal 1, r[:x]
    assert_equal 3, r[:w]
  end

  test 'place resolves against bounds' do
    reset
    Console.draw.within({ x: 0, y: 0, w: 100, h: 100 }) do
      # w/h inside place: are fractions of the bounds, so 0.1 of 100 is 10px.
      r = Console.draw.rect place: { x: 0.5, y: 0.5, w: 0.1, h: 0.1,
                                     anchor_x: 0.5, anchor_y: 0.5 }
      assert_equal 45, r[:x]
      assert_equal 45, r[:y]
      assert_equal 10, r[:w]
    end
  end

  test 'place treats w/h as fractions of the bounds' do
    reset
    Console.draw.within({ x: 0, y: 0, w: 200, h: 100 }) do
      r = Console.draw.rect place: { x: 0.0, y: 0.0, w: 0.5, h: 1.0 }
      assert_equal 100, r[:w], 'w: 0.5 of a 200px bounds should be 100'
      assert_equal 100, r[:h]
    end
  end

  test 'a top-level w/h overrides a place spec with absolute pixels' do
    reset
    Console.draw.within({ x: 0, y: 0, w: 1000, h: 1000 }) do
      r = Console.draw.rect place: { x: 0.5, y: 0.5, anchor_x: 0.5,
                                     anchor_y: 0.5 }, w: 32, h: 32
      assert_equal 32, r[:w]
      assert_equal 32, r[:h]
      assert_equal 484, r[:x]
    end
  end

  test 'top: anchors to the top of the screen' do
    reset
    r = Console.draw.rect x: 10, top: 100, w: 40, h: 30
    assert_equal 10, r[:x]
    assert_equal $args.grid.h - 130, r[:y]
  end

  test 'strip lays out from the top of the screen' do
    r = Console.strip 0, 64
    assert_equal 0, r[:x]
    assert_equal $args.grid.h - 64, r[:y]
    assert_equal 64, r[:h]
  end

  test 'bounds are restored even when the block raises' do
    before = Console.draw.bounds
    begin
      Console.draw.within({ x: 0, y: 0, w: 5, h: 5 }) { raise 'boom' }
    rescue
      nil
    end
    assert_equal before[:w], Console.draw.bounds[:w]
  end

  test 'nested within restores the inner bound' do
    Console.draw.within({ x: 0, y: 0, w: 100, h: 100 }) do
      Console.draw.within({ x: 0, y: 0, w: 10, h: 10 }) do
        assert_equal 10, Console.draw.bounds[:w]
      end
      assert_equal 100, Console.draw.bounds[:w]
    end
  end

  test 'sprite uses the texture natural size when w/h are omitted' do
    reset
    # A hand-written path is cart-relative, so the emitted primitive carries
    # the cart's file and not a console-root one.
    Console.draw.sprite path: 'sprites/star.png', x: 0, y: 0
    prim = outputs.sprites.last
    assert_equal 'carts/selftest/sprites/star.png', prim[:path]
    assert_equal 16, prim[:w]
    assert_equal 16, prim[:h]
  end

  test 'text pushes a label and returns the measured rect' do
    reset
    r = Console.draw.text 'hello', x: 0, y: 0
    assert outputs.labels.size > 0
    assert_equal 'hello', outputs.labels.last[:text]
    assert r[:w] > 0
    assert r[:h] > 0
  end

  test 'text align center centers the anchor' do
    reset
    Console.draw.text 'hi', x: 100, y: 0, align: :center
    assert_equal 0.5, outputs.labels.last[:anchor_x]
  end

  test 'text emits x/y as the anchor point, not a pre-shifted offset' do
    # DragonRuby positions a label relative to its own text box when
    # anchor_x/anchor_y are supplied. Shifting x by the anchor *and* passing
    # the anchor applies it twice, which pushed every centred string right by
    # half its width.
    reset
    rect = Console.draw.text 'hello', x: 100, y: 200, anchor_x: 0.5, anchor_y: 0.5
    label = outputs.labels.last
    assert_equal 100, label[:x]
    assert_equal 200, label[:y]
    assert_equal 0.5, label[:anchor_x]
    assert_equal 0.5, label[:anchor_y]
    # The reported rect is the true box (its x is the left edge, not the
    # anchor), and the anchor sits at the box centre.
    assert_almost_equal 100, rect[:x] + (rect[:w] / 2.0)
    assert_almost_equal 200, rect[:y] + (rect[:h] / 2.0)
    assert rect[:w] > 0
    assert rect[:h] > 0
  end

  test 'text without an anchor stays left/bottom aligned' do
    reset
    Console.draw.text 'hi', x: 7, y: 9
    label = outputs.labels.last
    assert_equal 7, label[:x]
    assert_equal 9, label[:y]
    assert_equal 0.0, label[:anchor_x]
    assert_equal 0.0, label[:anchor_y]
  end

  test 'measure matches the documented font metrics' do
    w, h = Console.draw.measure 'hello'
    assert_almost_equal 49.5, w, 0.6
    assert_almost_equal 22.0, h, 0.6
  end

  test 'bar clamps the fill to the track' do
    reset
    fill = Console.draw.bar({ x: 0, y: 0, w: 100, h: 10 }, 5, 10)
    assert_equal 50, fill
    assert_equal 100, Console.draw.bar({ x: 0, y: 0, w: 100, h: 10 }, 50, 10)
    assert_equal 0, Console.draw.bar({ x: 0, y: 0, w: 100, h: 10 }, -5, 10)
    assert_equal 0, Console.draw.bar({ x: 0, y: 0, w: 100, h: 10 }, 5, 0)
  end

  test 'grid returns one rect per cell' do
    reset
    cells = Console.draw.grid x: 0, y: 0, w: 100, h: 100, cols: 5, rows: 4
    assert_equal 20, cells.size
    assert outputs.borders.size >= 20
  end

  test 'thickness draws parallel line copies' do
    reset
    Console.draw.line 0, 0, 100, 0, :white, 3
    assert_equal 3, outputs.lines.size
  end
end

class TweenSuite
  include Console::Test

  test 'linear tween interpolates between from and to' do
    target = { v: 0 }
    t = Console::Tween.new target, :v, from: 0, to: 100, in: 10, now: 0
    assert_equal 0, t.progress(0).round
    assert_almost_equal 0.5, t.progress(5), 0.001
    assert_almost_equal 1.0, t.progress(10), 0.001
  end

  test 'easing curves are anchored at 0 and 1' do
    Console::Tween::EASINGS.each do |name, fn|
      assert_almost_equal 0, fn.call(0), 0.001, "#{name} at 0"
      assert_almost_equal 1, fn.call(1), 0.001, "#{name} at 1"
    end
  end

  test 'easing curves stay inside 0..1' do
    Console::Tween::EASINGS.each do |name, fn|
      next if name == :elastic # elasticOut overshoots on purpose
      0.upto(10) do |i|
        p = i / 10.0
        v = fn.call p
        assert_between v, -0.001, 1.001, "#{name} at #{p} was #{v}"
      end
    end
  end

  test 'elastic overshoots but stays bounded and anchored' do
    fn = Console::Tween::EASINGS[:elastic]
    assert_almost_equal 0, fn.call(0), 0.001
    assert_almost_equal 1, fn.call(1), 0.001
    peak = 0.0
    0.upto(20) { |i| peak = fn.call(i / 20.0) if fn.call(i / 20.0) > peak }
    assert peak > 1.0, 'expected elastic to overshoot past 1'
    assert_between peak, 1.0, 1.4
  end

  test 'tween reaches its target and reports done' do
    target = { v: 0 }
    t = Console.tweens.tween target, :v, from: 0, to: 100, in: 10, now: 0
    assert_equal 0, target[:v]
    t.update 5
    assert_between target[:v], 40, 60, 'should be roughly halfway at t=5'
    t.update 10
    assert_equal 100, target[:v]
    assert t.done?
  end

  test 'delay postpones the first write' do
    target = { v: 5 }
    t = Console::Tween.new target, :v, from: 0, to: 100, in: 5, delay: 60,
                            now: 0
    assert_equal 0, t.progress(0)
    assert_equal 0, t.progress(59)
    assert target[:v] > 0, 'should not start before the delay elapses'
  end

  test 'cancel removes a tween' do
    target = { v: 0 }
    Console.tweens.tween target, :v, from: 0, to: 10, in: 30
    assert Console.tweens.tweening?(target)
    Console.tweens.cancel_tweens target
    refute Console.tweens.tweening?(target)
  end

  test 'on_done fires exactly once' do
    count = 0
    target = { v: 0 }
    t = Console::Tween.new target, :v, from: 0, to: 1, in: 1, now: 0,
                            on_done: ->(finished) { count += 1 }
    t.capture!
    0.upto(5) { |i| t.update i }
    assert_equal 1, count
  end

  test 'yoyo returns to the start value' do
    target = { v: 0 }
    t = Console::Tween.new target, :v, from: 0, to: 10, in: 5, yoyo: true,
                            loops: 2, now: 0
    t.capture!
    0.upto(20) { |i| t.update i }
    assert_equal 0, target[:v].round
  end
end

class SceneSuite
  include Console::Test

  class Probe
    def initialize
      @log = []
    end

    def enter
      @log << :enter
    end

    def update
      @log << :update
    end

    def render
      @log << :render
    end

    def leave
      @log << :leave
    end

    def log
      @log
    end
  end

  def setup_probe(ctrl)
    klass = Class.new do
      attr_reader :log

      def initialize
        @log = []
      end

      def enter
        @log << :enter
      end

      def update
        @log << :update
      end

      def render
        @log << :render
        # Emit something real so the test can prove the hook reached the
        # renderer, not merely that a method ran.
        Console.draw.rect x: 0, y: 0, w: 2, h: 2, color: :white
      end

      def leave
        @log << :leave
      end
    end
    ctrl.define :one, klass
    ctrl.define :two, klass
    klass
  end

  test 'define registers a scene' do
    ctrl = Console::SceneController.new $args
    setup_probe ctrl
    assert ctrl.defined?(:one)
    assert_equal 2, ctrl.names.size
  end

  test 'goto activates enter and runs update/render' do
    ctrl = Console::SceneController.new $args
    klass = setup_probe ctrl
    ctrl.goto :one
    ctrl.run false
    assert_equal :one, ctrl.current_name
    inst = ctrl.instance
    assert_includes inst.log, :enter
    assert_includes inst.log, :update
    # `run false` means "advance logic but do not draw", so the render hook is
    # deliberately skipped. See the next test for the drawing case.
    refute_includes inst.log, :render
  end

  test 'run true dispatches render and it reaches the renderer' do
    ctrl = Console::SceneController.new $args
    setup_probe ctrl
    before = $args.outputs.sprites.size
    ctrl.goto :one
    ctrl.run true
    assert_includes ctrl.instance.log, :render
    assert $args.outputs.sprites.size > before,
           'scene :render was dispatched but produced no sprites'
  end

  test 'scene changes are committed at end of frame' do
    ctrl = Console::SceneController.new $args
    setup_probe ctrl
    ctrl.goto :one
    assert ctrl.pending?
    assert_nil ctrl.current_name
    ctrl.run false
    refute ctrl.pending?
    assert_equal :one, ctrl.current_name
  end

  test 'push adds depth and pop returns' do
    ctrl = Console::SceneController.new $args
    setup_probe ctrl
    ctrl.goto :one
    ctrl.run false
    ctrl.push :two
    ctrl.run false
    assert_equal 2, ctrl.depth
    assert_equal :two, ctrl.current_name
    ctrl.pop
    ctrl.run false
    assert_equal 1, ctrl.depth
    assert_equal :one, ctrl.current_name
  end

  test 'pushing an already-active scene is a no-op' do
    ctrl = Console::SceneController.new $args
    setup_probe ctrl
    ctrl.goto :one
    ctrl.run false
    ctrl.push :one
    ctrl.run false
    assert_equal 1, ctrl.depth
  end

  test 'goto fires the leave hook' do
    ctrl = Console::SceneController.new $args
    setup_probe ctrl
    ctrl.goto :one
    ctrl.run false
    first = ctrl.instance
    refute_includes first.log, :leave
    ctrl.goto :two
    ctrl.run false
    assert_includes first.log, :leave
    assert_equal :two, ctrl.current_name
  end

  test 'enter and leave hooks fire' do
    ctrl = Console::SceneController.new $args
    setup_probe ctrl
    seen = []
    ctrl.on_enter(:one) { seen << :entered }
    ctrl.on_leave(:one) { seen << :left }
    ctrl.goto :one
    ctrl.run false
    ctrl.goto :two
    ctrl.run false
    assert_includes seen, :entered
    assert_includes seen, :left
  end

  test 'per-scene state persists across visits' do
    ctrl = Console::SceneController.new $args
    setup_probe ctrl
    ctrl.store(:one)[:hp] = 7
    assert_equal 7, ctrl.store(:one)[:hp]
    ctrl.store(:one)[:hp] = 9
    assert_equal 9, ctrl.store(:one)[:hp]
  end
end

class EntitySuite
  include Console::Test

  def setup
    Console.entities.clear
  end

  test 'spawn assigns id, kind and geometry' do
    e = Console.entities.spawn nil, kind: :bullet, x: 5, y: 6, w: 7, h: 8
    assert_not_nil e[:id]
    assert_equal :bullet, e[:kind]
    assert_equal 5, e[:x]
    assert_equal 7, e[:w]
  end

  test 'spawn defaults geometry so every entity has a rect' do
    e = Console.entities.spawn nil, kind: :thing
    assert_equal 0, e[:x]
    assert_equal 16, e[:w]
  end

  test 'ids are unique' do
    a = Console.entities.spawn nil, kind: :thing
    b = Console.entities.spawn nil, kind: :thing
    assert a[:id] != b[:id]
  end

  test 'each_entity filters by kind' do
    Console.entities.spawn nil, kind: :enemy
    Console.entities.spawn nil, kind: :enemy
    Console.entities.spawn nil, kind: :coin
    seen = 0
    Console.entities.each(:enemy) { seen += 1 }
    assert_equal 2, seen
    assert_equal 2, Console.entities.count(:enemy)
    assert_equal 1, Console.entities.count(:coin)
  end

  test 'despawn removes an entity' do
    e = Console.entities.spawn nil, kind: :thing
    assert Console.entities.despawn(e)
    assert_equal 0, Console.entities.count(:thing)
  end

  test 'despawn_if bulk removes' do
    3.times { Console.entities.spawn nil, kind: :zombie }
    Console.entities.spawn nil, kind: :hero
    removed = Console.entities.despawn_if { |e| e[:kind] == :zombie }
    assert_equal 3, removed
    assert_equal 1, Console.entities.size
  end

  test 'colliding finds overlapping entities only' do
    Console.entities.spawn nil, kind: :wall, x: 0, y: 0, w: 10, h: 10
    Console.entities.spawn nil, kind: :wall, x: 100, y: 100, w: 10, h: 10
    hits = Console.entities.colliding({ x: 5, y: 5, w: 5, h: 5 }, :wall)
    assert_equal 1, hits.size
    assert_equal 0, hits[0][:x]
  end

  test 'move applies velocity' do
    e = Console.entities.spawn nil, kind: :thing, x: 0, y: 0
    Console.entities.move e, vx: 3, vy: -2
    assert_equal 3, e[:x]
    assert_equal(-2, e[:y])
  end

  test 'clear removes only one kind' do
    Console.entities.spawn nil, kind: :a
    Console.entities.spawn nil, kind: :b
    Console.entities.clear :a
    assert_equal 1, Console.entities.size
  end
end

class AnimationSuite
  include Console::Test

  def setup
    Console.anim.stop_all
  end

  test 'a sequence animation reports its state' do
    e = { id: 900_001, kind: :hero, w: 16, h: 16 }
    frame = Console.anim.play e, :idle, frames: ['a.png', 'b.png'],
                               frame_count: 2, fps: 60
    assert_not_nil frame
    assert Console.anim.playing?(900_001, :idle)
    assert_equal 2, frame.frame_count
  end

  test 'lock prevents a second animation from cutting in' do
    e = { id: 900_002, kind: :hero, w: 16, h: 16 }
    Console.anim.play e, :die, frames: ['a.png'], frame_count: 1,
                      repeat: false, lock: 600
    result = Console.anim.play e, :run, frames: ['b.png'], frame_count: 1
    assert_nil result
    assert Console.anim.playing?(900_002, :die)
  end

  test 'repeat=false eventually finishes' do
    e = { id: 900_003, kind: :hero, w: 16, h: 16 }
    frame = Console.anim.play e, :hit, frames: ['a.png'], frame_count: 1,
                              fps: 60, repeat: false
    assert frame.update(Kernel.tick_count + 1000)
    assert frame.finished?
  end

  test 'repeat=true never finishes' do
    e = { id: 900_004, kind: :hero, w: 16, h: 16 }
    frame = Console.anim.play e, :run, frames: ['a.png', 'b.png'],
                              frame_count: 2, fps: 60, repeat: true
    frame.update Kernel.tick_count + 100_000
    refute frame.finished?
  end

  test 'frame index stays inside the frame count' do
    e = { id: 900_005, kind: :hero, w: 16, h: 16 }
    frame = Console.anim.play e, :walk, frames: ['a.png', 'b.png', 'c.png'],
                              frame_count: 3, fps: 60, repeat: false
    0.upto(500) do |i|
      idx = frame.index Kernel.tick_count + i
      assert_between idx, 0, 2, "index #{idx} out of range"
    end
  end

  test 'sheet animations emit source crops' do
    e = { id: 900_006, kind: :hero, w: 16, h: 16 }
    Console.anim.play e, :walk, kind: :sheet, sheet: 'sprites/star.png',
                       frame_count: 4, frame_w: 16, frame_h: 16, fps: 60
    props = Console.anim.primitive_props e
    assert_equal 'carts/selftest/sprites/star.png', props[:path]
    assert_equal 0, props[:source_x]
    assert_equal 16, props[:source_w]
  end

  test 'stop removes an animation' do
    e = { id: 900_007, kind: :hero, w: 16, h: 16 }
    Console.anim.play e, :run, frames: ['a.png'], frame_count: 1
    assert Console.anim.active?(900_007)
    Console.anim.stop 900_007
    refute Console.anim.active?(900_007)
  end
end

class CameraSuite
  include Console::Test

  def setup
    Console.camera.bounds = nil
    Console.camera.zoom = 1.0
    Console.camera.stop_following
    Console.camera.x = 0.0
    Console.camera.y = 0.0
  end

  test 'no camera means identity transform' do
    r = Console.draw.transform({ x: 5, y: 6, w: 1, h: 1 })
    assert_equal 5, r[:x]
  end

  test 'to_screen and to_world are inverses' do
    cam = Console.camera
    cam.bounds = nil
    p = cam.to_world 100, 200
    s = cam.to_screen p[:x], p[:y]
    assert_almost_equal 100, s[:x], 0.001
    assert_almost_equal 200, s[:y], 0.001
  end

  test 'apply pushes and pops the transform' do
    refute Console.camera.active?
    Console.camera.apply do
      assert Console.camera.active?
    end
    refute Console.camera.active?
  end

  test 'zoom of 1 with no offset leaves geometry alone' do
    Console.camera.apply do
      r = Console.draw.transform({ x: 3, y: 4, w: 5, h: 6 })
      assert_equal 3, r[:x]
      assert_equal 5, r[:w]
    end
  end

  test 'zoom scales geometry about the screen centre' do
    Console.camera.zoom = 2.0
    grid = $args.grid
    cx = grid.w / 2.0
    Console.camera.apply do
      r = Console.draw.transform({ x: cx - 5, y: 0, w: 10, h: 10 })
      assert_equal 20, r[:w], 'zoom should double the width'
      assert_almost_equal cx, Console::Geom.center_x(r), 0.001
    end
  end

  test 'bounds clamping keeps the view inside the world' do
    cam = Console.camera
    cam.bounds = { x: 0, y: 0, w: 400, h: 400 }
    cam.update
    assert Console.camera.x <= 400
  end
end

class UISuite
  include Console::Test

  def reset
    Console.draw.outputs.sprites.clear
    Console.draw.outputs.labels.clear
    Console.draw.outputs.borders.clear
  end

  test 'label returns a measured rect' do
    reset
    r = Console.ui.label x: 10, y: 10, text: 'hello'
    assert r[:w] > 0
  end

  test 'panel returns an inset content rect' do
    reset
    r = Console.ui.panel x: 0, y: 0, w: 200, h: 200, pad: 10
    assert_equal 10, r[:x]
    assert_equal 180, r[:w]
  end

  test 'panel with a title shrinks the content rect' do
    reset
    without = Console.ui.panel x: 0, y: 0, w: 200, h: 200, pad: 0
    reset
    with = Console.ui.panel x: 0, y: 0, w: 200, h: 200, pad: 0,
                            title: 'STATS', title_h: 40
    assert with[:h] < without[:h]
  end

  test 'bar reports a clamped fraction' do
    reset
    r = Console.ui.bar x: 0, y: 0, w: 100, value: 5, max: 10
    assert_almost_equal 0.5, r[:perc], 0.001
    r2 = Console.ui.bar x: 0, y: 0, w: 100, value: 50, max: 10
    assert_equal 1.0, r2[:perc]
    r3 = Console.ui.bar x: 0, y: 0, w: 100, value: -5, max: 10
    assert_equal 0.0, r3[:perc]
  end

  test 'bar handles a zero max without dividing by zero' do
    reset
    r = Console.ui.bar x: 0, y: 0, w: 100, value: 5, max: 0
    assert_equal 0.0, r[:perc]
  end

  test 'pips makes one cell per unit' do
    reset
    r = Console.ui.pips x: 0, y: 0, w: 100, value: 3, max: 5
    assert_equal 5, r[:cells].size
  end

  test 'button returns interaction flags' do
    reset
    r = Console.ui.button x: 0, y: 0, w: 100, h: 40, text: 'GO', id: 'go'
    assert_equal 100, r[:rect][:w]
    assert_equal false, r[:clicked]
    assert_equal 'go', r[:id]
  end

  test 'button fires on_click when the block reports a click' do
    reset
    fired = []
    # Stand in for the pointer being over the button and going down.
    Console.input.pointer[:x] = 50
    Console.input.pointer[:y] = 20
    Console.input.pointer[:down] = true
    Console.input.pointer[:pressed] = true
    r = Console.ui.button x: 0, y: 0, w: 100, h: 40, text: 'GO',
                          id: 'fired', on_click: ->(id) { fired << id }
    assert_equal 1, fired.size
    assert_equal 'fired', fired[0]
  end

  test 'menu returns the selected index' do
    reset
    m = Console.ui.menu x: 0, y: 0, items: %w[A B C], key: 'test_menu_a'
    assert_between m[:index], 0, 2
    assert_equal 3, m[:items].size
  end

  test 'menu items lay out vertically without overlapping' do
    reset
    m = Console.ui.menu x: 0, y: 0, w: 200, items: %w[A B C], row_h: 20,
                         gap: 5, key: 'test_menu_b'
    a = m[:items][0]
    b = m[:items][1]
    assert_equal a[:y] + a[:h] + 5, b[:y]
  end

  test 'checkbox toggles on click' do
    reset
    Console.input.pointer[:x] = 10
    Console.input.pointer[:y] = 10
    Console.input.pointer[:down] = true
    Console.input.pointer[:pressed] = true
    key = 'test_checkbox'
    Console.ui_store.delete key
    r1 = Console.ui.checkbox x: 0, y: 0, key: key, text: 'on'
    assert_equal true, r1[:value], 'the click should have switched it on'
    assert_equal true, r1[:changed]
    Console.input.pointer[:pressed] = false
    r2 = Console.ui.checkbox x: 0, y: 0, key: key, text: 'on'
    assert_equal true, r2[:value], 'no further press, so it stays on'
    assert_equal false, r2[:changed]
    Console.input.pointer[:pressed] = true
    r3 = Console.ui.checkbox x: 0, y: 0, key: key, text: 'on'
    assert_equal false, r3[:value], 'a second click switches it back off'
  end
end

class InputSuite
  include Console::Test

  test 'every documented action exists in the snapshot' do
    Console.input.refresh
    Console::Input::ACTIONS.each do |action|
      held = Console.input.held?(action)
      is_boolean = (held == true) || (held == false)
      assert_equal true, is_boolean,
                   "#{action} answered held? with #{held.inspect}" 
      assert_equal false, Console.input.pressed?(action)
    end
  end

  test 'held? never raises for an unknown action' do
    assert_equal false, Console.input.held?(:not_a_real_action)
    assert_equal false, Console.input.pressed?(:not_a_real_action)
  end

  test 'pointer is always available' do
    p = Console.input.pointer
    assert_not_nil p
    assert_not_nil p[:x]
    assert_not_nil p[:y]
  end

  test 'axis reads are in range' do
    assert_between Console.input.axis_x, -1.0, 1.0
    assert_between Console.input.axis_y, -1.0, 1.0
  end

  test 'text collection is opt-in' do
    assert_equal false, Console.input.text_enabled
    assert_equal 0, Console.input.typed.size
  end
end

class RuntimeSuite
  include Console::Test

  test 'console is booted' do
    assert Console.booted?
  end

  test 'version is exposed once and matches the version file' do
    assert_equal Console::Version::STRING, Console::VERSION
    assert_equal '0.1.0', Console::Version::STRING
  end

  test 'screen tracks the live grid' do
    assert_equal $args.grid.w, Console.screen[:w]
    assert_equal $args.grid.h, Console.screen[:h]
  end

  test 'rand_int stays inside its range' do
    200.times do
      v = Console::API.instance_method(:rand_int).bind(Object.new).call(3, 7)
      assert_between v, 3, 7
    end
  end

  test 'rand_between stays inside its range' do
    probe = Object.new
    probe.extend Console::API
    200.times do
      v = probe.rand_between(-2.0, 2.0)
      assert_between v, -2.0, 2.0
    end
  end

  test 'pick and chance stay in range' do
    probe = Object.new
    probe.extend Console::API
    list = [1, 2, 3]
    50.times { assert_includes list, probe.pick(list) }
    assert_nil probe.pick([])
    assert_equal false, probe.chance(0.0)
    assert_equal true, probe.chance(1.0)
  end

  test 'every subsystem is present' do
    %i[draw input ui entities anim audio camera tweens scenes].each do |m|
      assert_not_nil Console.send(m), "#{m} should be wired up"
    end
  end

  test 'draw is connected to the camera' do
    assert_equal Console.camera, Console.draw.camera
  end

  test 'the cart loader sees this cart' do
    assert_equal 'selftest', Console.cart_name
  end

  # --- single-cart publishing (see ./publish-cart) ----------------------
  #
  # A published build ships one cart and an entry point that pins it, so the
  # pin has to outrank both ways of asking for a different cart.

  test 'an unpinned loader is not pinned' do
    loader = Console::CartLoader.new $args
    assert_equal false, loader.pinned?
    assert_nil loader.pinned_name
  end

  test 'a pinned loader reports the pinned cart' do
    loader = Console::CartLoader.new($args).pin 'arcade'
    assert_equal true, loader.pinned?
    assert_equal 'arcade', loader.pinned_name
    assert_equal 'arcade', loader.requested_name
  end

  test 'a pin outranks --cart and the CART env var' do
    # cli_arguments carries whatever this run was started with; the pinned
    # name must win over both of the documented selection routes.
    loader = Console::CartLoader.new($args).pin 'arcade'
    assert_equal 'arcade', loader.requested_name
  end

  test 'pin coerces its argument to a string' do
    loader = Console::CartLoader.new($args).pin :arcade
    assert_equal 'arcade', loader.pinned_name
    assert_equal 'arcade', loader.requested_name
  end

  test 'pin returns the loader so it can be chained' do
    loader = Console::CartLoader.new $args
    assert_equal loader, loader.pin('arcade')
  end

  # publish-cart pins 'carts/space', not 'space', so a staged build stays
  # pinned to its directory even after the cart is copied into place.
  test 'a pin may be a path and resolves like any other target' do
    loader = Console::CartLoader.new($args).pin 'carts/arcade'
    assert_equal 'carts/arcade', loader.pinned_name
    assert_equal 'carts/arcade', loader.requested_dir
    assert_equal 'arcade', loader.cart_name(loader.requested_dir)
    assert loader.cart?(loader.requested_dir)
  end

  test 'a pin does not degrade to the default when the cart is absent' do
    # The dangerous case is a typo shipping some *other* cart as the game. A
    # pinned loader must keep reporting the pinned name even when it is not on
    # disk, so the boot path can abort instead of quietly falling back.
    #
    # `run` is deliberately not called here: aborting calls DR.request_quit,
    # and a unit test must not quit the process it is running in. The abort
    # itself is covered end to end by ./publish-cart, which boots a staged
    # build with its cart removed.
    loader = Console::CartLoader.new($args).pin 'no_such_cart'
    refute_includes loader.available, 'no_such_cart'
    assert_equal 'no_such_cart', loader.requested_name
    refute_equal Console::CartLoader::DEFAULT_CART, loader.requested_name
  end

  test 'api mixin does not collide with cart or scene hook names' do
    # A cart/scene hook that shares a name with an API method gets shadowed,
    # which is how `draw.sprite` inside a scene once re-entered the scene's own
    # `draw` and blew the stack. Guard the reserved names.
    reserved = %i[setup update render enter leave assets sprites sounds]
    api = Console::API.instance_methods
    clashing = api.select { |m| reserved.include?(m) }
    assert_equal 0, clashing.size,
                 "API methods shadow hook names: #{clashing.join(', ')}"
  end

  test 'scene render hook does not shadow the draw object' do
    probe = Class.new do
      attr_reader :calls
      def initialize
        @calls = []
      end

      def render
        @calls << :render
      end
    end
    ctrl = Console::SceneController.new $args
    ctrl.define :probe, probe
    ctrl.goto :probe
    ctrl.run true
    assert_includes ctrl.instance.calls, :render
  end

  test 'api mixin exposes the documented surface' do
    api = Console::API.instance_methods
    required = %i[goto push_scene pop_scene current_scene scene_data
                  draw input ui spawn despawn each_entity animate sfx music
                  tween after every sprite auto_sprite debug
                  center overlaps? inside? percent strip row_at
                  ui_store camera background rand_between
                  asset assets_root shared_assets]
    missing = required.select { |m| !api.include?(m) }
    assert_equal 0, missing.size, "missing API methods: #{missing.join(', ')}"
  end

  test 'background colour is applied' do
    assert_not_nil $args.outputs.background_color
  end

  test 'outputs accept our primitives without warnings' do
    $args.outputs.sprites << { x: 0, y: 0, w: 4, h: 4, path: :solid }
    $args.outputs.labels << { x: 0, y: 0, text: 'selftest' }
    assert_not_nil $args.outputs.sprites
  end
end

class Selftest
  include Console::Test

  def self.setup
    Console.show_hud = true
  end

  def update
    # Keep the frame alive; the loader quits us after the report.
  end

  def render
    draw.text 'console selftest', x: 20, y: 20, color: :accent
    ui.hud
  end
end
# ---------------------------------------------------------------------------
# Console::Map -- LDTK loading.
#
# The fixture is a trimmed but structurally real .ldtk export: a world holding
# one level, an IntGrid collision layer, an entity layer with all the field
# types that behave differently, and a tile layer.
#
# It deliberately includes a Point field WITH cx/cy and a Point field WITHOUT
# any, because those are the two cases that break a naive loader: the first has
# no 'value' key at all, and the second has no 'value' and no cx/cy.
# ---------------------------------------------------------------------------
class MapSuite
  include Console::Test

  FIXTURE = 'fixtures/sample.ldtk'

  def map(options = {})
    Console::Map.load FIXTURE, options
  end

  test 'loads a level out of an ldtk export' do
    m = map
    assert_not_nil m
    assert_equal 'Level_0', m.identifier
    assert_equal 320.0, m.width
    assert_equal 160.0, m.height
  end

  test 'missing map warns and returns nil rather than crashing' do
    assert_nil Console::Map.load('fixtures/definitely_not_here.ldtk')
  end

  test 'entity identifier becomes the console kind' do
    m = map
    # 'Enemy' -> :enemy, with no naming from the cart at all. Platform and
    # Block are absent because both declare themselves solid in the map, and a
    # solid is collision rather than something to spawn.
    assert_equal [:coin, :enemy], m.entities.map { |e| e[:kind] }.sort
  end

  test 'entity position and size come from ldtk' do
    enemy = map.entities_of('Enemy').first
    assert_equal 64.0, enemy[:x]
    assert_equal 16.0, enemy[:w]
    assert_equal 16.0, enemy[:h]
  end

  test 'ldtk y is flipped into console bottom-left space' do
    m = map
    enemy = m.entities_of('Enemy').first
    # LDTK puts the enemy at y=64 counting DOWN from a 160px level, and the
    # entity is 16 tall, so its bottom edge in console space is 160-64-16=80.
    assert_equal 80.0, enemy[:y]
  end

  test 'flip_y false keeps raw ldtk coordinates' do
    enemy = map(flip_y: false).entities_of('Enemy').first
    assert_equal 64.0, enemy[:y]
  end

  test 'primitive field types survive parsing with their types intact' do
    enemy = map.entities_of('Enemy').first
    # The whole point of typed fields: an Int arrives as an Integer, not "3".
    assert_equal 3, enemy[:health]
    assert_equal Integer, enemy[:health].class
    assert_equal 1.5, enemy[:speed]
    assert_equal Float, enemy[:speed].class
    assert_equal 'boss', enemy[:label]
    assert_equal false, enemy[:dead]
  end

  test 'field identifiers are snake_cased' do
    enemy = map.entities_of('Enemy').first
    assert_equal 3, enemy[:health]      # Health
    assert_equal 10, map.entities_of('Coin').first[:value] # Value
  end

  test 'a Point field with coordinates becomes an x/y hash' do
    enemy = map.entities_of('Enemy').first
    assert_equal({ x: 96.0, y: 112.0 }, enemy[:home_point])
  end

  test 'an empty Point field is dropped rather than stored as nil' do
    # This is the trap. A Point has no 'value' key at all, so a loader that
    # reads f['value'] gets nil, and in mruby an absent key RAISES when chained
    # into. Storing nil would also shadow the cart's own spawn default.
    enemy = map.entities_of('Enemy').first
    refute_includes enemy.keys, :empty
    assert_not_nil enemy[:health]
  end

  test 'field_value never raises on a point without cx/cy' do
    field = { '__identifier' => 'Empty', '__type' => 'Point' }
    assert_nil Console::Map.field_value(field)
  end

  test 'field_value handles every primitive type through value' do
    %w[Int Float String Bool].each do |type|
      assert_equal 7, Console::Map.field_value({ '__type' => type, 'value' => 7 })
    end
  end

  test 'field_value reads the modern __value key as well as legacy value' do
    # LDTK renamed the payload key from `value` to `__value`. A loader that
    # knows only the old spelling loses EVERY field on a modern export, and
    # loses them silently -- the level still loads, just bare.
    assert_equal 7, Console::Map.field_value({ '__type' => 'Int', '__value' => 7 })
    assert_equal true, Console::Map.field_value({ '__type' => 'Bool', '__value' => true })
    # The old spelling still loads, so 1.x exports do not break.
    assert_equal 7, Console::Map.field_value({ '__type' => 'Int', 'value' => 7 })
    # Modern wins if an export somehow carries both.
    assert_equal 9, Console::Map.field_value({ '__type' => 'Int', '__value' => 9, 'value' => 7 })
  end

  test 'a modern ldtk export loads its fields and its solid entities' do
    # End-to-end version of the __value test, and the exact combination that
    # used to be broken: on a modern export every field read as nil, so a
    # Solid flag would have been invisible and the entity would have stayed
    # non-collidable with nothing to indicate why. Built inline through
    # from_hash rather than committed as a second fixture file.
    data = {
      'worlds' => [{
        'identifier' => 'W', 'iid' => 'w1',
        'levels' => [{
          'identifier' => 'Level_0', 'pxWid' => 320, 'pxHei' => 160,
          'layerInstances' => [{
            '__type' => 'Entities', '__identifier' => 'Entities', 'iid' => 'l1',
            'entityInstances' => [
              {
                '__identifier' => 'Enemy', 'iid' => 'e1', 'defUid' => 1,
                'width' => 16, 'height' => 16, 'px' => [64, 64],
                'fieldInstances' => [
                  { '__identifier' => 'Health', '__type' => 'Int', '__value' => 9, 'defUid' => 10 },
                  { '__identifier' => 'Solid', '__type' => 'Bool', '__value' => false, 'defUid' => 11 }
                ]
              },
              {
                '__identifier' => 'Platform', 'iid' => 'e2', 'defUid' => 3,
                'width' => 48, 'height' => 8, 'px' => [160, 96],
                'fieldInstances' => [
                  { '__identifier' => 'Solid', '__type' => 'Bool', '__value' => true, 'defUid' => 11 }
                ]
              }
            ]
          }]
        }]
      }]
    }

    m = Console::Map.from_hash data

    # A plain entity keeps its fields...
    assert_equal 1, m.entities.size
    assert_equal 9, m.entities_of('Enemy').first[:health]
    # ...and Solid: false is correctly NOT enough to make it a solid.
    assert_equal 1, m.solids.size
    assert_equal 48.0, m.solids.first[:w]
    assert_equal 56.0, m.solids.first[:y]
  end

  test 'intgrid non-zero cells become solid rects' do
    m = map
    # The fixture's bottom row is solid across all 20 columns. Counted by
    # position rather than via `solids.size`, because the map also contributes
    # entity-derived solids and this test is only about the IntGrid layer.
    assert_equal 20, m.solids.select { |s| s[:y] == 0.0 }.size
    first = m.solids.first
    assert_equal 0.0, first[:x]
    assert_equal 0.0, first[:y]
    assert_equal 16.0, first[:w]
    assert_equal 16.0, first[:h]
  end

  test 'intgrid rows are flipped into console space' do
    # Row 9 (the last) is the bottom row of the level, so in console space it
    # must sit at y=0 -- not at y=144, which is where LDTK counts it from.
    assert_equal 0.0, m_solids_bottom_y
  end

  def m_solids_bottom_y
    map.solids.map { |s| s[:y] }.min
  end

  test 'one_way_value marks pass-through cells' do
    m = map(one_way_value: 1)
    assert_equal true, m.solids.first[:one_way]
    # Without the option they are ordinary solids.
    assert_equal false, map.solids.first[:one_way]
  end

  test 'a one_way entity is solid without any cart-side list' do
    m = map
    # The fixture's Platform carries OneWay: true and nothing else. A
    # pass-through platform is still a platform, so it becomes collision on its
    # own -- plain `load_map 'Level_0.ldtk'`, no solid_entities: option.
    refute_includes m.entities.map { |e| e[:kind] }, :platform
    plat = m.solids.find { |s| s[:w] == 48.0 && s[:h] == 8.0 }
    assert_not_nil plat
    assert_equal true, plat[:one_way]
    assert_equal 160.0, plat[:x]
    assert_equal 56.0, plat[:y] # 160 - 96 - 8, flipped into console space
  end

  test 'a solid bool field makes an entity solid with no cart-side list' do
    m = map
    # Block declares Solid: true and is NOT one-way, so this covers the rule
    # independently of the one_way path above.
    refute_includes m.entities.map { |e| e[:kind] }, :block
    blk = m.solids.find { |s| s[:w] == 32.0 && s[:h] == 16.0 }
    assert_not_nil blk
    assert_equal false, blk[:one_way]
    assert_equal 16.0, blk[:x]
    assert_equal 48.0, blk[:y] # 160 - 96 - 16
  end

  test 'entity-derived solids have the same shape as intgrid ones' do
    # A cart reads `solids` without caring which layer a rect came from.
    map.solids.each do |s|
      assert_equal :solid, s[:kind]
      assert_not_nil s[:one_way]
    end
  end

  test 'a body falls onto a solid entity straight out of the map' do
    m = map
    plat = m.solids.find { |s| s[:w] == 48.0 && s[:h] == 8.0 }
    assert_not_nil plat
    # The whole point of the Platform carrying OneWay: a body dropped from
    # above it lands on top rather than dropping through to the floor.
    b = Console::Body.new(x: plat[:x] + 8.0, y: plat[:y] + 60.0,
                          w: 16.0, h: 16.0, gravity: 0.5)
    300.times { b.update m.solids }
    assert b.grounded?
    assert_equal plat[:y] + plat[:h], b.y # 64.0 -- resting on the surface
  end

  test 'one_way entity passes from below but a solid one blocks' do
    m = map
    plat = m.solids.find { |s| s[:w] == 48.0 && s[:h] == 8.0 }
    blk  = m.solids.find { |s| s[:w] == 32.0 && s[:h] == 16.0 }
    # Both bodies start at y=30: clear of the floor at y=16, and below both
    # rects, so the only thing that can stop them is the entity above. Note
    # that positive vy is RISING here -- the same sense as `jump`.
    rising = ->(target) {
      b = Console::Body.new(x: target[:x] + 8.0, y: 30.0,
                            w: 16.0, h: 16.0, gravity: 0.0)
      b.vy = 8.0
      40.times { b.update m.solids }
      b
    }

    # Rising through the one_way Platform: straight past it.
    through = rising.call plat
    assert through.y > plat[:y] + plat[:h]

    # Rising into the Solid Block: stopped against its underside.
    stopped = rising.call blk
    assert_equal blk[:y], stopped.y + stopped.h
  end

  test 'solid_entities option turns entities into solids' do
    plain = map
    # Coin declares neither Solid nor OneWay, so the option is the ONLY thing
    # that can promote it -- which is what makes this a test of the option
    # rather than a restatement of the two field rules.
    assert_includes plain.entities.map { |e| e[:kind] }, :coin
    m = map(solid_entities: ['Coin'])
    refute_includes m.entities.map { |e| e[:kind] }, :coin
    # The Coin moved out of `entities`, and one extra solid appeared.
    assert_equal plain.entities.size - 1, m.entities.size
    assert_equal plain.solids.size + 1, m.solids.size
  end

  test 'tiles are collected with console-space positions' do
    m = map
    assert_equal 2, m.tiles.size
    # src=[0,0] px=[0,144] in a 160px level, 16px tiles -> console y = 0.
    assert_equal([0.0, 0.0], m.tiles.first[:px])
  end

  test 'entities_of accepts either ldtk or console spelling' do
    m = map
    assert_equal 1, m.entities_of('Enemy').size
    assert_equal 1, m.entities_of(:enemy).size
    assert_equal 1, m.entities_of('enemy').size
  end

  test 'spawn_all pushes entities into the store with their kinds' do
    m = map
    before = Console.entities.count(:enemy)
    created = m.spawn_all
    # Coin and Enemy only: the two entities that declare themselves solid in
    # the map are collision, not things to spawn.
    assert_equal 2, created.size
    assert_equal before + 1, Console.entities.count(:enemy)
    created.each { |e| Console.entities.despawn e }
  end

  test 'to_s is informative and does not raise' do
    assert_not_nil map.to_s
  end
end

# ---------------------------------------------------------------------------
# Console::Body -- kinematic platformer movement.
#
# Solids are written out by hand rather than loaded from the map so that every
# expected number is checkable on paper.
# ---------------------------------------------------------------------------
class BodySuite
  include Console::Test

  def solid(x, y, w, h, one_way = false)
    { x: x.to_f, y: y.to_f, w: w.to_f, h: h.to_f, one_way: one_way }
  end

  # A floor spanning the whole width at the bottom of a 200px world.
  def floor_solids
    [solid(0, 0, 200, 16)]
  end

  test 'a body falls under gravity and comes to rest on the floor' do
    b = Console::Body.new(x: 50, y: 100, w: 16, h: 16, gravity: 1.0)
    100.times { b.update floor_solids }
    assert b.grounded?
    # Resting exactly on top of the floor: y == floor top (0 + 16).
    assert_equal 16.0, b.y
    assert_equal 0.0, b.vy
  end

  test 'gravity is a positive magnitude that pulls down' do
    # Bottom-left origin, so falling means y DECREASES.
    b = Console::Body.new(x: 50, y: 100, w: 16, h: 16, gravity: 1.0)
    y_before = b.y
    b.update []
    assert b.y < y_before
    assert b.vy < 0
  end

  test 'landed? fires on exactly one frame, not on every resting frame' do
    b = Console::Body.new(x: 50, y: 100, w: 16, h: 16, gravity: 1.0)
    landings = 0
    150.times do
      b.update floor_solids
      landings += 1 if b.landed?
    end
    # This is the edge-trigger that makes `if body.landed?` safe to write.
    assert_equal 1, landings
  end

  test 'max_fall clamps terminal velocity' do
    b = Console::Body.new(x: 50, y: 190, w: 16, h: 16,
                          gravity: 1.0, max_fall: 6.0)
    60.times { b.update [] }
    assert b.vy >= -6.0
  end

  test 'a wall stops horizontal motion and snaps flush' do
    wall = [solid(100, 0, 16, 200)]
    b = Console::Body.new(x: 50, y: 100, w: 16, h: 16, gravity: 0.0)
    10.times do
      b.vx = 10
      b.update wall
    end
    assert b.wall?
    assert_equal :right, b.wall_dir
    # flush against the wall's left face: 100 - 16
    assert_equal 84.0, b.x
    assert_equal 0.0, b.vx
  end

  test 'a body slides down a wall instead of sticking to it' do
    # The reason collision resolves one axis at a time: a wall zeroes vx but
    # leaves vy alone, so gravity keeps pulling and the body slides.
    wall = [solid(100, 60, 16, 60)]
    b = Console::Body.new(x: 80, y: 100, w: 16, h: 16, gravity: 1.0)
    y_before = b.y
    3.times do
      b.vx = 10
      b.update wall
    end
    assert b.wall?
    assert_equal 0.0, b.vx
    assert b.y < y_before
  end

  test 'a fast body does not tunnel through a thin floor' do
    # The case that justifies substepping. In ONE frame at vy = -200 the body
    # would cross a 16px floor entirely, a single-frame overlap test would
    # report nothing, and the body would land underneath the world -- which
    # looks like a gameplay bug rather than a physics one.
    b = Console::Body.new(x: 50, y: 100, w: 16, h: 16, gravity: 0.0)
    b.vy = -200.0
    b.update floor_solids
    assert b.grounded?
    assert_equal 16.0, b.y
    assert b.y > 0, 'body must not have passed through the floor'
  end

  test 'a wall stops the body when step-up is disabled' do
    # The default. Auto-stepping lets a cart walk up a wall it meant to be
    # blocked by, so it is opt-in.
    step = [solid(0, 0, 200, 16), solid(100, 16, 16, 16)]
    b = Console::Body.new(x: 80, y: 16, w: 16, h: 16, gravity: 1.0)
    40.times do
      b.vx = 2
      b.update step
    end
    assert_equal 84.0, b.x
    assert_equal 16.0, b.y
  end

  test 'a body steps over a low ledge when step_height allows it' do
    # Floor plus a 16px step. With step-up the body lifts onto the step rather
    # than stopping dead against its face.
    step = [solid(0, 0, 200, 16), solid(100, 16, 16, 16)]
    b = Console::Body.new(x: 80, y: 16, w: 16, h: 16,
                          gravity: 1.0, step_height: 16.0)
    40.times do
      b.vx = 2
      b.update step
    end
    # Walking right, fully past the 16px step (which spans x=100..116).
    assert b.x > 116, "expected to clear the step, stuck at x=#{b.x}"
    # The step is a bump on a full-width floor, so having walked over it the
    # body correctly settles back onto the floor rather than staying raised.
    assert_equal 16.0, b.y
  end

  test 'step-up does not trigger for a wall taller than step_height' do
    wall = [solid(0, 0, 200, 16), solid(100, 16, 16, 100)]
    b = Console::Body.new(x: 80, y: 16, w: 16, h: 16,
                          gravity: 1.0, step_height: 8.0)
    30.times do
      b.vx = 2
      b.update wall
    end
    assert_equal 84.0, b.x
  end

  test 'jumping sets upward velocity and clears grounded' do
    b = Console::Body.new(x: 50, y: 100, w: 16, h: 16, gravity: 1.0)
    100.times { b.update floor_solids }
    assert b.grounded?
    b.jump 10
    assert_equal 10.0, b.vy
    b.update floor_solids
    assert_equal false, b.grounded?
  end

  test 'rising into a ceiling stops upward motion' do
    ceil = [solid(0, 100, 200, 16)]
    b = Console::Body.new(x: 50, y: 16, w: 16, h: 16, gravity: 0.0)
    b.jump 200
    # One frame: these flags describe the frame that just resolved, and are
    # cleared at the start of the next one.
    b.update ceil
    assert b.ceiling?
    # Head stops flush under the ceiling: 100 - 16.
    assert_equal 84.0, b.y
    assert_equal 0.0, b.vy
  end

  test 'one_way solids are pass-through from below' do
    plat = [solid(0, 60, 200, 8, true)]
    b = Console::Body.new(x: 50, y: 16, w: 16, h: 16, gravity: 0.0)
    b.jump 200
    b.update plat
    # Above the platform (60 + 8 = 68) without being stopped by it.
    assert b.y > 68, "expected to pass through, stopped at y=#{b.y}"
    assert_equal false, b.grounded?
  end

  test 'one_way solids still catch a falling body from above' do
    plat = [solid(0, 60, 200, 8, true)]
    b = Console::Body.new(x: 50, y: 120, w: 16, h: 16, gravity: 1.0)
    60.times { b.update plat }
    assert b.grounded?
    assert_equal 68.0, b.y
  end

  test 'a one_way platform does not block a body already below it' do
    plat = [solid(0, 60, 200, 8, true)]
    b = Console::Body.new(x: 50, y: 10, w: 16, h: 16, gravity: 1.0)
    60.times { b.update plat }
    # Fell straight past it and kept going.
    assert_equal false, b.grounded?
    assert b.y < 60
  end

  test 'a body can jump back up through its own one_way platform' do
    plat = [solid(0, 60, 200, 8, true)]
    b = Console::Body.new(x: 50, y: 120, w: 16, h: 16, gravity: 1.0)
    60.times { b.update plat }
    assert b.grounded?
    assert_equal 68.0, b.y
    b.jump 40
    b.update plat
    # The only way to get above the platform is to have passed up through it.
    assert b.y > 68, "expected to pass up through, stopped at y=#{b.y}"
  end

  test 'body binds to an entity and writes movement back to it' do
    entity = { x: 50, y: 100, w: 16, h: 16, kind: :hero }
    b = Console::Body.new(entity: entity, gravity: 1.0)
    assert_equal 16.0, b.w
    100.times { b.update floor_solids }
    assert_equal b.y, entity[:y]
    assert_equal 16.0, entity[:y]
  end

  test 'friction damps horizontal speed' do
    b = Console::Body.new(x: 50, y: 100, w: 16, h: 16,
                          gravity: 0.0, friction: 0.5)
    b.vx = 10
    b.update []
    assert_equal 5.0, b.vx
  end

  test 'friction defaults to leaving velocity alone' do
    b = Console::Body.new(x: 50, y: 100, w: 16, h: 16, gravity: 0.0)
    b.vx = 10
    b.update []
    assert_equal 10.0, b.vx
  end

  test 'fall_distance resets on landing' do
    b = Console::Body.new(x: 50, y: 100, w: 16, h: 16, gravity: 1.0)
    10.times { b.update [] }
    assert b.fall_distance > 0
    200.times { b.update floor_solids }
    assert_equal 0.0, b.fall_distance
  end

  test 'an empty solid list is not an error' do
    b = Console::Body.new(x: 0, y: 0, w: 16, h: 16, gravity: 1.0)
    b.update nil
    b.update []
    assert_equal false, b.grounded?
  end

  test 'body exposes a drawable entity even when unbound' do
    b = Console::Body.new(x: 10, y: 20, w: 16, h: 16)
    assert_equal 10.0, b.entity[:x]
    assert_equal :body, b.entity[:kind]
  end
end
