# Console::Entity -- a flat, fast entity store.
#
# Entities are plain Hashes with `x`, `y`, `w`, `h`, `kind` and a unique `id`.
# Keeping them Hash-shaped matters: DragonRuby renders Hash primitives faster
# than class instances, and a hash entity can be passed straight to
# `args.outputs.sprites <<` when it has a `path`.
#
#   spawn Bullet, kind: :bullet, x: 100, y: 100,
#                     sprite: 'star', vx: 4, vy: 0
#   each_entity :bullet do |b|
#     move b, vx: b.vx, vy: b.vy
#     despawn b if off_screen?(b)
#   end
#
# `kind` is the tag used for querying, animation lookup (sprites/<kind>/<state>)
# and collision groups.
#
# Two attributes plug an entity into platformer physics with no extra
# bookkeeping -- despawning the entity removes either:
#
#   spawn :hero,  x: 64, y: 200, body: { gravity: 0.4 }  # stepped every frame
#   spawn :plank, x: 96, y: 0, w: 28, h: 40, solid: true # bodies collide with it
module Console
  class EntityStore
    attr_reader :entities
    attr_accessor :next_id

    def initialize
      @entities = []
      @by_id = {}
      @next_id = 1
      @world_solids = []
    end

    def size
      @entities.size
    end

    # Create an entity. `klass` may be a Class (which must respond to
    # `defaults` or take a Hash) or any Symbol used purely as documentation.
    #
    # Returns the entity Hash.
    def spawn(klass = nil, attributes = {})
      kind = attributes[:kind]
      kind ||= klass if klass.is_a?(Symbol)
      e = { id: @next_id }
      @next_id += 1

      if klass.is_a?(Class)
        if klass.respond_to?(:spawn_defaults)
          e.merge! klass.spawn_defaults
        end
        if klass.respond_to?(:defaults)
          e.merge! klass.defaults
        end
      end

      e[:kind] = kind.to_sym if kind
      e.merge! attributes
      e[:kind] = kind.to_sym if kind && !e[:kind]
      e[:x] ||= 0.0
      e[:y] ||= 0.0
      e[:w] ||= 16
      e[:h] ||= 16

      # `body:` (a Hash of Body options, or true) attaches a body the console
      # steps every frame. It is resolved after the merge so a class's
      # `defaults` can declare one too.
      spec = e[:body]
      if spec.is_a?(Body)
        spec.entity = e
      elsif spec
        attach_body e, spec.is_a?(Hash) ? spec : {}
      end

      @entities << e
      @by_id[e[:id]] = e
      e
    end

    def despawn(entity)
      return false unless entity
      id = entity[:id]
      @by_id.delete id
      @entities.delete entity
      true
    end

    def despawn_if(&block)
      doomed = @entities.select(&block)
      doomed.each { |e| despawn e }
      doomed.size
    end

    def [](id)
      @by_id[id]
    end

    def clear(kind = nil)
      if kind.nil?
        @entities = []
        @by_id = {}
        return
      end
      @entities.select { |e| e[:kind] == kind.to_sym }.each { |e| despawn e }
    end

    def count(kind = nil)
      return @entities.size if kind.nil?
      @entities.count { |e| e[:kind] == kind.to_sym }
    end

    def any?(kind)
      @entities.any? { |e| e[:kind] == kind.to_sym }
    end

    def all(kind = nil)
      return @entities.dup if kind.nil?
      @entities.select { |e| e[:kind] == kind.to_sym }
    end

    # Iterates a snapshot, so the block may despawn (or spawn) freely: deleting
    # from the live array mid-loop would silently skip the next entity. An
    # entity despawned earlier in the same pass is not yielded.
    def each(kind = nil, &block)
      k = kind.nil? ? nil : kind.to_sym
      @entities.dup.each do |e|
        next if k && e[:kind] != k
        next unless @by_id[e[:id]].equal?(e)
        block.call e
      end
      @entities.size
    end

    def each_with_kind(kind, &block)
      each kind, &block
    end

    # --- bodies and solids ---------------------------------------------

    # Static level geometry every attached body collides with, on top of the
    # entities marked `solid: true`. `spawn_level` sets this to the map's
    # solids; it survives `clear`, because a level outlives its entities.
    attr_reader :world_solids

    def world_solids=(list)
      @world_solids = list || []
    end

    # Give an existing entity (one spawned by a map, say) a body the console
    # steps every frame. Returns the Body, also reachable as entity[:body].
    def attach_body(entity, options = {})
      entity[:body] = Body.new(options.merge(entity: entity))
    end

    # Everything a body collides with: the world solids plus every live entity
    # with a truthy `solid:` (`one_way: true` makes it a pass-through platform).
    # Solid entities are read fresh each frame, so tweening one's h grows its
    # collision with its sprite, and despawning it removes both.
    def solids
      out = @world_solids.dup
      @entities.each { |e| out << e if e[:solid] && !e[:dead] }
      out
    end

    # The Body of every entity that has one.
    def bodies
      out = []
      @entities.each { |e| out << e[:body] if e[:body].is_a?(Body) }
      out
    end

    # Advance every attached body one frame. Console.tick calls this once per
    # frame (frozen under a pausing overlay), so carts never call it.
    #
    # A body that is itself solid (a crate other bodies stand on) never
    # collides with its own entity. Returns the number of bodies stepped.
    def step_bodies
      movers = @entities.select { |e| e[:body].is_a?(Body) }
      return 0 if movers.empty?

      all = solids
      movers.each do |e|
        list = e[:solid] ? all.reject { |s| s.equal?(e) } : all
        e[:body].update list
      end
      movers.size
    end

    # --- queries ---------------------------------------------------------

    # All entities of `kind` intersecting `rect`.
    def colliding(rect, kind = nil)
      out = []
      @entities.each do |e|
        next if kind && e[:kind] != kind.to_sym
        next if e[:dead]
        next unless e.intersect_rect? rect
        out << e
      end
      out
    end

    # The first entity of `kind` intersecting `rect`.
    def colliding_one(rect, kind = nil)
      @entities.each do |e|
        next if kind && e[:kind] != kind.to_sym
        next if e[:dead]
        return e if e.intersect_rect? rect
      end
      nil
    end

    def nearest(rect, kind = nil)
      best = nil
      best_d = nil
      c = Geom.center rect
      @entities.each do |e|
        next if kind && e[:kind] != kind.to_sym
        d = Geometry.distance c, Geom.center(e)
        if best_d.nil? || d < best_d
          best = e
          best_d = d
        end
      end
      best
    end

    # --- motion ----------------------------------------------------------

    # move entity, vx: 3, vy: -2   (one options hash; see Console::API)
    def move(entity, options = {})
      entity[:x] = entity[:x] + (options[:vx] || 0)
      entity[:y] = entity[:y] + (options[:vy] || 0)
      entity
    end

    def move_to(entity, x, y)
      entity[:x] = x
      entity[:y] = y
      entity
    end

    # Aim vx/vy from the entity's centre at the target's centre.
    def toward(entity, target, speed)
      c = Geom.center entity
      t = Geom.center target
      dx = t[:x] - c[:x]
      dy = t[:y] - c[:y]
      len = Math.sqrt((dx * dx) + (dy * dy))
      if len == 0
        entity[:vx] = 0.0
        entity[:vy] = 0.0
      else
        entity[:vx] = dx / len * speed
        entity[:vy] = dy / len * speed
      end
      entity
    end

    # The geometric centre of `rect`.
    def center(rect)
      Geom.center rect
    end
  end

  # Sprite-resolution + animation glue for entities.
  module EntityDraw
    extend self

    # Resolve an entity's sprite. Prefers an active animation, then
    # `entity[:sprite]`, then `entity[:path]`, then the generated placeholder.
    def sprite_path(console, entity)
      if entity[:sprite_frames] && entity[:sprite_frames].size > 0
        i = entity[:sprite_frame] || 0
        return entity[:sprite_frames][i % entity[:sprite_frames].size]
      end
      return entity[:sprite] if entity[:sprite]
      return entity[:path] if entity[:path]
      return entity[:kind] if entity[:kind]
      :solid
    end

    # Draw an entity, honouring an active animation, tint, alpha, flips and
    # rotation. Routes through Draw so the camera transform applies.
    #
    #   draw_entity entity
    #   draw_entity entity, angle: spin
    def draw_entity(console, entity, spec = {})
      prim = { x: entity[:x], y: entity[:y],
               w: entity[:w], h: entity[:h] }

      # An active animation wins; otherwise fall back to the entity's own
      # sprite, then its path, then its kind. Without the fallback an entity
      # with no matching animation folder renders as an empty box.
      frame = console.anim.primitive_props entity
      if frame
        prim = prim.merge frame
      else
        prim[:path] = sprite_path(console, entity)
      end

      %i[flip_horizontally flip_vertically angle angle_anchor_x
         angle_anchor_y source_x source_y source_w source_h z].each do |k|
        prim[k] = entity[k] if entity[k]
      end

      if entity[:tint] || entity[:alpha]
        prim = prim.merge Palette.to_hash(entity[:tint] || :white, entity[:alpha])
      end

      prim = prim.merge(spec) if spec && spec.size > 0
      console.draw.sprite prim
    end
  end
end