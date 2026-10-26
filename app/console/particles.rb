# Console::Particles -- fire-and-forget particle bursts.
#
#   burst x: 100, y: 200                          # a shower of sparks
#   burst x: 100, y: 200, shake: 6                # ...plus camera.shake 6
#   burst :explosion, x: 100, y: 200              # a preset (shakes too)
#   burst :smoke, x: 100, y: 200, color: :gray    # a preset, overridden
#
#   camera.apply do
#     draw_particles                              # world space, like entities
#   end
#
# Particles are plain hashes stepped by the console in the same frame slot as
# tweens, so they freeze under a pausing overlay. They are never drawn on
# their own: call `draw_particles` where they belong in the layering.
module Console
  class Particles
    DEFAULTS = { count: 24, color: :warn, speed: 4.0, life: 30, size: 3,
                 gravity: 0.15, drag: 0.96, angle: 90, spread: 360,
                 grow: 0, alpha: 255 }

    # Overrides of DEFAULTS. A cart may add its own:
    #   Console::Particles::PRESETS[:confetti] = { color: %i[good bad accent] }
    PRESETS = {
      sparks: {},
      explosion: { count: 40, color: %i[warn accent2 bad], speed: 6.0,
                   life: 36, size: 5, gravity: 0.05, drag: 0.92,
                   shake: [8, 14] },
      smoke: { count: 12, color: :muted, speed: 1.0, life: 60, size: 6,
               grow: 0.3, gravity: -0.03, drag: 0.98, spread: 60, alpha: 160 },
      dust: { count: 10, color: :muted, speed: 2.0, life: 20, size: 2,
              gravity: 0.1, spread: 160 }
    }

    attr_reader :list

    def initialize
      @list = []
    end

    # Emit `count` particles at x/y. `angle` (degrees, 90 is up) and `spread`
    # aim the burst; speed and life vary by up to half so it never looks
    # stamped. `color:` may be a list, picked per particle. `shake:` is a
    # camera.shake magnitude, or [magnitude, ticks].
    def burst(preset = nil, options = {})
      # mruby binds `burst x: 1` to the first optional param.
      if preset.is_a?(Hash)
        options = preset
        preset = nil
      end
      base = PRESETS[preset || :sparks]
      unless base
        Console.warn "particle preset not found: #{preset} (using sparks)"
        base = {}
      end
      o = DEFAULTS.merge(base).merge(options)
      colors = o[:color]
      colors = [colors] unless colors.is_a?(Array) && !colors[0].is_a?(Numeric)
      o[:count].to_i.times do
        a = (o[:angle] + ((rand - 0.5) * o[:spread])) * Math::PI / 180.0
        s = o[:speed] * (0.5 + (rand * 0.5))
        life = (o[:life] * (0.5 + (rand * 0.5))).to_i + 1
        @list << { x: o[:x] || 0, y: o[:y] || 0,
                   vx: Math.cos(a) * s, vy: Math.sin(a) * s,
                   life: life, max: life, size: o[:size],
                   color: colors[(rand * colors.size).to_i],
                   gravity: o[:gravity], drag: o[:drag], grow: o[:grow],
                   alpha: o[:alpha] }
      end
      shake = o[:shake]
      Console.camera.shake(*(shake.is_a?(Array) ? shake : [shake])) if shake && Console.camera
      self
    end

    def update
      @list.each do |p|
        p[:vx] *= p[:drag]
        p[:vy] = (p[:vy] * p[:drag]) - p[:gravity]
        p[:x] += p[:vx]
        p[:y] += p[:vy]
        p[:size] += p[:grow]
        p[:life] -= 1
      end
      @list.reject! { |p| p[:life] <= 0 }
    end

    # Each particle is a square centred on its position, fading as it dies.
    def draw(draw)
      @list.each do |p|
        s = p[:size]
        draw.rect x: p[:x] - (s / 2.0), y: p[:y] - (s / 2.0), w: s, h: s,
                  color: p[:color], alpha: (p[:alpha] * p[:life] / p[:max]).to_i
      end
    end

    def count
      @list.size
    end

    def clear
      @list = []
    end
  end
end
