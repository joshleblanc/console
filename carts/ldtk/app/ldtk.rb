# Cart: ldtk
#
# The LDTK pipeline end to end: load a real .ldtk export, spawn its entities,
# and run a body against the solids it yields -- those harvested from the
# IntGrid layer, plus every entity that declares itself solid in the map.
#
#   ./run --cart ldtk
#
# It exists partly as a demo and partly as a canary -- it is the one cart that
# exercises Console::Map and Console::Body together, so `./smoke` fails if a
# change to either breaks the real loading path rather than just the unit
# tests.
TITLE = 'ldtk pipeline'

class Ldtk
  LEVEL = 'maps/Level_0.ldtk'
  GRAVITY = 0.3
  SPEED = 4.0
  JUMP = 9.0

  def setup
    # Deliberately no `solid_entities:` list here. The Platform and Block
    # entities in Level_0.ldtk carry OneWay: true and Solid: true, so the map
    # decides they are collision and they arrive in @map.solids on their own --
    # both landable, neither named in console code.
    @map = load_map LEVEL
    return unless @map

    # Entities become console entities by name: 'Enemy' -> :enemy, carrying
    # its LDTK fields as attributes.
    @spawned = spawn_level @map
    @ship = spawn :ship,
                  kind: :hero,
                  x: 32, y: 120,
                  w: 16, h: 16,
                  sprite: :hero

    # One option hash: mruby would otherwise bind a trailing key: value list
    # to the first positional argument.
    @body = body entity: @ship, gravity: GRAVITY, max_fall: 8.0

    debug "ldtk: #{@spawned.size} entities, #{@map.solids.size} solids"
  end

  def update
    return unless @body

    @body.vx = input.axis_x * SPEED
    @body.jump JUMP if input.pressed?(:accept) && @body.grounded?
    @body.update @map.solids

    # A one-line use of an LDTK Int field: it arrived as a real Integer.
    each_entity(:enemy) do |e|
      next unless e[:health] && e[:health] <= 0
      despawn e
    end

    # A Point field arrived as a hash; land the player on it.
    @home = @map.entities_of('Enemy').first
    @body.x = @home[:home_point][:x] if @body.grounded? && input.pressed?(:pause)
  end

  def render
    return unless @map

    # Solids, drawn in world space.
    camera.bounds = { x: 0, y: 0, w: @map.width, h: @map.height }
    camera.apply do
      @map.solids.each do |s|
        draw.rect x: s[:x], y: s[:y], w: s[:w], h: s[:h], color: :panel
      end
      @map.tiles.each do |t|
        draw.sprite path: :solid, x: t[:px][0], y: t[:px][1],
                    w: t[:size], h: t[:size], color: :muted
      end
      each_entity do |e|
        next if e[:kind] == :hero
        draw.rect x: e[:x], y: e[:y], w: e[:w], h: e[:h], color: :accent2
      end
      draw_entity @ship if @ship
    end

    draw.text "ldtk  grounded=#{@body && @body.grounded?}  solids=#{@map.solids.size}",
              x: 20, top: 24, size_enum: -3, color: :text
    draw.text 'arrows move  space jumps',
              x: 20, top: 48, size_enum: -3, color: :muted
  end
end
