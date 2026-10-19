# Console::Camera -- a 2D scroll/zoom camera.
#
# The camera owns the world -> screen offset used by every draw call inside
# `camera.apply`. UI drawn outside the block stays screen-locked, which is the
# usual split (world in `apply`, HUD after).
#
#   camera.look_at(entity)                 # follow an entity
#   camera.shake(6, 12)                    # magnitude 6, 12 ticks
#   camera.apply do
#     draw.sprite(x: entity.x, y: entity.y, path: :hero)
#   end
#
# Offsets are computed so the focused point lands at the screen's centre, and
# the view is clamped so you never see past the world bounds unless you opt out
# with `camera.unbounded`.
module Console
  class Camera
    attr_reader :shake_magnitude
    attr_accessor :x, :y, :zoom, :bounds, :target_x, :target_y

    def initialize(args)
      @args = args
      @x = 0.0
      @y = 0.0
      @zoom = 1.0
      @shake_magnitude = 0.0
      @shake_until = 0
      @bounds = nil
      @target_x = nil
      @target_y = nil
      @offset_stack = []
      @follow = nil
    end

    def args
      @args
    end

    def grid
      @args.grid
    end

    # Centre of the screen. Named `screen_center_*` so it cannot be confused
    # with Geom.center_x, which takes a rect.
    def screen_center_x
      grid.w / 2.0
    end

    def screen_center_y
      grid.h / 2.0
    end

    # --- configuration ----------------------------------------------------

    # The world rectangle the camera may show. nil means unbounded.
    def bounds=(value)
      @bounds = value
    end

    def unbounded
      @bounds = nil
      self
    end

    def zoom=(value)
      @zoom = value <= 0 ? 1.0 : value
    end

    # --- focus ------------------------------------------------------------

    def follow(entity)
      @follow = entity
      self
    end

    def stop_following
      @follow = nil
      self
    end

    def following?
      !@follow.nil?
    end

    # Point the camera at a world position (or an entity) for one frame.
    def look_at(thing)
      if thing.is_a?(Hash) && thing[:x]
        @target_x = thing[:x]
        @target_y = thing[:y]
      end
      self
    end

    def shake(magnitude, ticks = 10)
      @shake_magnitude = magnitude
      @shake_until = Kernel.tick_count + ticks
      self
    end

    # --- per-frame -------------------------------------------------------

    def update
      if @follow
        cx = @target_x || Geom.center_x(@follow)
        cy = @target_y || Geom.center_y(@follow)
      else
        cx = @target_x || (@x + screen_center_x)
        cy = @target_y || (@y + screen_center_y)
      end
      @target_x = nil
      @target_y = nil

      desired_x = cx - screen_center_x
      desired_y = cy - screen_center_y

      @x = desired_x
      @y = desired_y
      clamp_to_bounds
      self
    end

    def shake_offset_x
      return 0.0 unless shaking?
      (rand - 0.5) * 2 * @shake_magnitude
    end

    def shake_offset_y
      return 0.0 unless shaking?
      (rand - 0.5) * 2 * @shake_magnitude
    end

    def shaking?
      Kernel.tick_count < @shake_until
    end

    # --- transform --------------------------------------------------------

    # Current total offset, including shake.
    def offset_x
      @x + shake_offset_x
    end

    def offset_y
      @y + shake_offset_y
    end

    # Convert a world point to screen space.
    def to_screen(wx, wy)
      { x: (wx - offset_x) * @zoom + (screen_center_x * (1 - @zoom)),
        y: (wy - offset_y) * @zoom + (screen_center_y * (1 - @zoom)) }
    end

    # Convert a screen point to world space (for mouse input).
    def to_world(sx, sy)
      { x: (sx - (screen_center_x * (1 - @zoom))) / @zoom + offset_x,
        y: (sy - (screen_center_y * (1 - @zoom))) / @zoom + offset_y }
    end

    # Hash-style access, so `tween camera, :zoom, to: 2.0` works like it does
    # on any entity hash.
    def [](key)
      send key
    end

    def []=(key, value)
      send "#{key}=", value
    end

    # Pointer position in world space, accounting for camera and shake.
    def pointer_world
      p = @args.inputs.mouse
      to_world p.x, p.y
    end

    # --- drawing ----------------------------------------------------------

    # Run the block with the camera applied to all coordinates.
    #
    # Coordinates are transformed by pushing a translate offset that Draw reads.
    def apply
      @offset_stack.push({ x: offset_x, y: offset_y, zoom: @zoom })
      begin
        yield self
      ensure
        @offset_stack.pop
      end
    end

    def active?
      @offset_stack.size > 0
    end

    def current_offset
      active? ? @offset_stack.last : { x: 0, y: 0, zoom: 1.0 }
    end

    # The world-space rect currently on screen (for culling / minimaps).
    def visible_rect
      bl = to_world 0, 0
      { x: bl[:x], y: bl[:y], w: grid.w / @zoom, h: grid.h / @zoom }
    end

    # True when a world rect overlaps the visible area.
    def visible?(r)
      v = visible_rect
      r[:x] < v[:x] + v[:w] && (r[:x] + r[:w]) > v[:x] &&
        r[:y] < v[:y] + v[:h] && (r[:y] + r[:h]) > v[:y]
    end

    private

    # Keep the visible area inside @bounds. The view spans
    # offset + c - c/zoom .. offset + c + c/zoom on each axis (c being the
    # screen centre), so that is the range the offset is clamped to.
    def clamp_to_bounds
      return if @bounds.nil?
      return if @bounds[:x].nil? || @bounds[:y].nil?
      @x = clamp_axis @x, @bounds[:x], @bounds[:w], screen_center_x
      @y = clamp_axis @y, @bounds[:y], @bounds[:h], screen_center_y
    end

    def clamp_axis(value, start, size, half)
      view_half = half / @zoom
      min = start - half + view_half
      max = start + size - half - view_half
      # A world smaller than the view on this axis is centred, not pinned to
      # one edge.
      return start + (size / 2.0) - half if max < min
      value.clamp(min, max)
    end
  end
end