# Cart: hello
#
# The smallest interesting cart. Read it top to bottom: this is the whole API
# surface a prototype needs.
#
#   ./run --cart hello
#
# It has no scenes and no assets. Everything is drawn from shapes and generated
# textures, which is the point: you can see a game before you have art.
TITLE = 'hello'

class Hello
  # Optional. Declare short names for assets here; anything under ./sprites
  # is already reachable by name without this.
  def self.assets
    {}
  end

  # Called once, when the console boots.
  def setup
    @burst = 0.0
    # No art yet? Generate it. These are real textures the cart can draw.
    auto_sprite :hello_badge, 48, 48, :accent, :checker
    auto_sprite :hello_dot, 24, 24, :accent2, :circle
    auto_sprite :hello_ring, 40, 40, :good, :ring
    sfx_or_note :hello
  end

  # Called every frame.
  def update
    # A 0..1 ramp that loops forever -- handy for idle motion.
    @wave = oscillate 0.4
    # Decay whatever the button kicked off.
    @burst -= 0.015
    @burst = 0.0 if @burst < 0
  end

  # Called every frame, after update. Use it for a HUD or overlay.
  def render
    # A top bar, laid out from the top of the screen.
    draw.within strip(0, 64) do
      draw.text 'hello from a cart', place: { x: 0.02, y: 0.5,
                                             anchor_y: 0.5 },
                size_px: 30, color: :accent
      draw.text "t+#{tick_count}", place: { x: 0.98, y: 0.5,
                                           anchor_x: 1.0, anchor_y: 0.5 },
                color: :muted
    end

    # A titled panel with a list inside it.
    content = ui.panel x: 40, top: 96, w: 420, h: 230,
                       title: 'the whole surface'
    lines = [
      'draw.text / draw.rect / draw.sprite',
      'ui.panel / ui.bar / ui.button',
      'spawn / animate / tween',
      'sfx / music / camera',
      'scene / goto / push_scene'
    ]
    lines.each_with_index do |line, i|
      draw.text line,
                x: content[:x],
                y: content[:y] + content[:h] - ((i + 1) * 28) + 20,
                color: :text
    end

    # A button that does something: kick off a burst that eases back down.
    b = ui.button x: 40, top: 380, w: 180, h: 44, text: 'pulse it',
                  id: 'pulse'
    @burst = 1.0 if b[:clicked]

    # A progress bar driven by a looping wave.
    ui.bar x: 40, top: 470, w: 420, h: 20,
           value: (@wave * 100).round, max: 100, color: :accent, border: true

    # Generated textures, floating, growing on a burst.
    scale = 1.0 + (Console::Tween::EASINGS[:out].call(@burst) * @burst * 0.6)
    draw.within strip(96, 300, 900) do
      draw.sprite place: { x: 0.70, y: 0.5, anchor_x: 0.5, anchor_y: 0.5 },
                  path: sprite(:hello_badge), w: 64 * scale, h: 64 * scale
      draw.sprite place: { x: 0.78, y: 0.3, anchor_x: 0.5, anchor_y: 0.5 },
                  path: sprite(:hello_dot), w: 24, h: 24
      draw.sprite place: { x: 0.84, y: 0.7, anchor_x: 0.5, anchor_y: 0.5 },
                  path: sprite(:hello_ring), w: 48, h: 48
    end

    draw.text 'F1 hud   ESC quit',
              x: screen[:w] - 20, y: top(24), anchor_x: 1.0,
              color: :muted, size_enum: -3

    DR.request_quit if input.pressed?(:cancel)
  end

  # A cart can ask the console for a sound by name. Without a sounds/ folder
  # the console just skips it, so a cart runs silently by default.
  def sfx_or_note(name)
    return if audio.resolve(name)
    debug "no sound registered for #{name}"
  end
end