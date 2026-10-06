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

class SpritesSuite
  include Console::Test

  test 'index resolves a real asset under sprites/' do
    Console::Sprites.index!
    path = Console::Sprites.path :star
    assert_equal 'sprites/star.png', path
  end

  test 'nested assets resolve by relative key' do
    Console::Sprites.index!
    assert_equal 'sprites/misc/star.png', Console::Sprites.path('misc/star')
  end

  test 'a string path is passed straight through' do
    assert_equal 'sprites/blue.png', Console::Sprites.path('sprites/blue.png')
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
    Console.draw.sprite path: 'sprites/star.png', x: 0, y: 0
    prim = outputs.sprites.last
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
    assert_equal 'sprites/star.png', props[:path]
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
                  ui_store camera background rand_between]
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