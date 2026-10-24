# Cart: widgets
#
# A gallery of everything the UI toolkit can draw, laid out from the top of
# the screen. Useful as a live reference while styling a cart.
#
#   ./bin/run --cart widgets
#
# Keyboard: TAB is not mapped, so use the arrow keys / dpad to move between
# rows, SPACE or gamepad A to activate, ESC to unfocus a slider.
TITLE = 'widget gallery'

class Widgets
  ITEMS = %w[one two three].freeze

  def setup
    auto_sprite :chip_tex, 12, 12, :accent2, :checker
    auto_sprite :orb, 20, 20, :good, :circle
    auto_sprite :crate, 20, 20, :warn, :frame

    @clicks = 0
    @slider_value = 40
    @toggles = { grid: true, trails: false, shake: true }
    @menu_index = 0

    # A tween that runs forever, purely to show easing curves on screen.
    @tweening = true
    ui_store['gallery_slider'] = 40
  end

  def update
    @orbit = tick_count
    if input.pressed?(:accept)
      @clicks += 1
      sfx :click
    end
  end

  def render
    background :dark

    # --- header ----------------------------------------------------------
    draw.within strip(0, 56) do
      draw.text 'WIDGET GALLERY',
                place: { x: 0.02, y: 0.5, anchor_y: 0.5 },
                size_px: 26, color: :accent
      draw.text "clicks: #{@clicks}",
                place: { x: 0.98, y: 0.5, anchor_x: 1.0, anchor_y: 0.5 },
                color: :muted
    end

    indicators
    interactive
    chooser
    geometry

    draw.text 'F1 hud',
              x: screen[:w] - 20, y: top(16), anchor_x: 1.0,
              size_enum: -3, color: :muted
  end

  # Column one: read-only indicators.
  def indicators
    c = ui.panel x: 30, top: 80, w: 390, h: 420, title: 'INDICATORS'
    # Start below the panel title, which is drawn at the panel's top edge.
    row = c[:y] + c[:h] - 26

    put_row c, row, 'bar'
    ui.bar x: c[:x], y: row - 46, w: c[:w], h: 22,
           value: 60, max: 100, color: :accent, border: true
    row -= 84

    put_row c, row, 'bar with counts'
    ui.bar x: c[:x], y: row - 46, w: c[:w], h: 22,
           value: 24, max: 40, color: :good, text: 'hp', show_counts: true
    row -= 84

    put_row c, row, 'pips'
    ui.pips x: c[:x], y: row - 36, w: 300, h: 14,
            value: 3, max: 5, color: :warn
    row -= 74

    put_row c, row, 'label and chip'
    ui.label x: c[:x], y: row - 30, text: 'a label'
    ui.chip x: c[:x] + 130, y: row - 38, text: 'a chip'
    row -= 66

    put_row c, row, 'generated textures'
    draw.sprite path: sprite(:chip_tex), x: c[:x], y: row - 40, w: 24, h: 24
    draw.sprite path: sprite(:orb),
                x: c[:x] + 40 + (Math.sin(@orbit * 0.05) * 10),
                y: row - 40, w: 24, h: 24
    draw.sprite path: sprite(:crate),
                x: c[:x] + 100, y: row - 40, w: 24, h: 24
  end

  # Column two: things you can press, toggle and drag.
  def interactive
    c = ui.panel x: 440, top: 80, w: 390, h: 420, title: 'INTERACTIVE'

    b = ui.button x: c[:x], y: c[:y] + c[:h] - 46, w: 180, h: 40,
                  text: 'PRESS ME', id: 'press'
    ui.button x: c[:x] + 196, y: c[:y] + c[:h] - 46, w: 180, h: 40,
              text: 'OFF', id: 'off', disabled: true
    ui.button x: c[:x], y: c[:y] + c[:h] - 98, w: c[:w], h: 44,
              text: b[:clicked] ? 'THANKS!' : 'WIDE BUTTON', id: 'wide'

    @toggles.keys.each_with_index do |key, idx|
      cx = c[:x] + ((idx % 2) * 200)
      cy = c[:y] + c[:h] - 140 - ((idx / 2) * 34)
      ui.checkbox x: cx, y: cy, key: "opt_#{key}", text: key.to_s
    end

    sl = ui.slider x: c[:x], y: c[:y] + c[:h] - 232, w: 300, h: 26,
                   key: 'gallery_slider', min: 0, max: 100, step: 5,
                   value: @slider_value
    @slider_value = sl[:value]
    draw.text sl[:focused] ? 'arrows adjust, ESC unfocuses' : 'click to focus',
              x: c[:x], y: c[:y] + c[:h] - 262,
              color: (sl[:focused] ? :accent : :muted), size_enum: -2

    ui.panel x: c[:x], y: c[:y] + c[:h] - 300, w: c[:w], h: 30,
             color: :panel_d
    draw.text "value: #{@slider_value}",
              x: c[:x] + 10, y: c[:y] + c[:h] - 292, color: :text
  end

  # Column three: the keyboard/gamepad navigable menu.
  def chooser
    c = ui.panel x: 850, top: 80, w: 400, h: 420, title: 'MENU'
    m = ui.menu x: c[:x], y: c[:y] + 26, w: c[:w], items: ITEMS,
                key: 'gallery_menu', row_h: 40, gap: 8
    @menu_index = m[:index]
    draw.text 'arrows / dpad to move', x: c[:x], y: c[:y] + 196,
              color: :muted, size_enum: -2
    draw.text 'space / A to pick', x: c[:x], y: c[:y] + 218,
              color: :muted, size_enum: -2
    draw.text "selected: #{ITEMS[@menu_index] || '-'}",
              x: c[:x], y: c[:y] + 262, size_px: 20, color: :text
    draw.text "clicked: #{m[:clicked] || '-'}",
              x: c[:x], y: c[:y] + 292, color: :good
  end

  # Bottom strip: bounds-relative layout plus the easing curves.
  def geometry
    geo = ui.panel x: 30, top: 520, w: 1220, h: 170, title: 'GEOMETRY'
    draw.within geo do
      draw.text 'draw.within(bounds) + place:',
                place: { x: 0.0, y: 0.84 }, color: :muted, size_enum: -2
      cells = draw.grid place: { x: 0.0, y: 0.42, w: 0.30, h: 0.30 },
                        cols: 6, rows: 3, color: :accent
      draw.text "#{cells.size} cells from cols: and rows:",
                place: { x: 0.0, y: 0.18 }, color: :text
      draw.text 'easing curves:',
                place: { x: 0.40, y: 0.84 }, color: :muted, size_enum: -2
      easing_strip
    end
  end

  # A small caption above a widget, positioned from the panel's bottom edge.
  def put_row(c, row, caption)
    draw.text caption, x: c[:x], y: row, color: :muted, size_enum: -2
  end

  # A row of squares rising under each easing curve, so the shapes are visible
  # rather than merely asserted.
  def easing_strip
    names = %i[linear in out in_out smooth elastic bounce]
    # Laid out inside the GEOMETRY panel's own bounds, so it cannot overflow.
    base = draw.bounds
    inner = inset({ x: base[:x] + (base[:w] * 0.40), y: base[:y] + 10,
                    w: base[:w] * 0.58, h: base[:h] - 30 }, 4)
    slot = inner[:w] / names.size
    p = tick_count % 60 / 60.0
    names.each_with_index do |name, i|
      fn = Console::Tween::EASINGS[name]
      h = fn.call(p) * (inner[:h] - 18)
      bx = inner[:x] + (i * slot)
      draw.rect x: bx, y: inner[:y], w: slot - 8, h: inner[:h] - 14,
                 color: :panel_d
      draw.rect x: bx, y: inner[:y], w: slot - 8, h: h, color: :accent
      draw.text name.to_s, x: bx, y: inner[:y] + inner[:h] - 12,
                size_enum: -4, color: :muted
    end
  end
end