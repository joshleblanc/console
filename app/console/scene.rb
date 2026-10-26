# Console::Scene -- the scene controller.
#
# DragonRuby has no scene system; every sample hand-rolls a `current_scene` /
# `next_scene` pair. This module formalises that, adds a stack, and gives each
# scene four optional hooks:
#
#   enter     called once when the scene becomes active
#   update    every frame while active
#   render    every frame while active
#   leave     called once when the scene stops being active
#
# The hook is called `render`, not `draw`: `draw` is the console's rendering
# object (`draw.rect`, `draw.sprite`), and a scene that defined `draw` would
# shadow it and recurse.
#
# A scene is a class (instantiated on entry) or a Hash of hook lambdas, each
# called with the Hash itself:
#
#   scene :title, TitleScene
#   scene :play, PlayScene
#   scene :credits, { render: ->(_) { Console.draw.text 'thanks', x: 10, y: 10 } }
#
#   goto :play                 # replace the whole stack
#   push :pause                # overlay, keeps :play underneath (paused)
#   push :hud, pause: false, transparent: true   # :play keeps running + shows
#   pop                        # back to :play
#
# Scene changes are committed at the END of the frame, so calling goto from
# inside update never leaves the frame half-run. Each scene gets its own state
# hash under `args.state.console.scenes[name]`, so leaving a scene and coming
# back does not lose data.
module Console
  # A registered scene definition.
  class SceneDef
    attr_reader :name, :klass, :options

    def initialize(name, klass = nil, options = {})
      @name = name.to_sym
      @klass = klass
      @options = options
    end

    # Build the per-scene instance. `kind` is :class, :block (a Hash of hook
    # lambdas, e.g. `{ update: ->(s) { ... } }`), or :none.
    def kind
      return :class if @klass.is_a?(Class)
      return :block if @klass.is_a?(Hash)
      :none
    end
  end

  class SceneController
    attr_reader :defs, :stack
    attr_accessor :current

    def initialize(args)
      @args = args
      @defs = {}
      @stack = []
      @current = nil
      @current_instance = nil
      @pending = nil
      @pending_push = false
      @pending_pop = false
      @pending_clear = false
      @pending_opts = {}
      # Overlay options per pushed scene name: { pause:, transparent:, dim: }.
      @layers = {}
      @enter_hooks = {}
      @leave_hooks = {}
      @history = []
    end

    def args
      @args
    end

    def tick_count
      Kernel.tick_count
    end

    # --- registration -----------------------------------------------------

    def define(name, klass = nil, options = {})
      d = SceneDef.new name, klass, options
      mix_in_api d.klass
      @defs[d.name] = d
      d
    end

    # Give a scene class the console's API as bare method calls, so a scene can
    # say `draw.rect` / `spawn` / `sfx` instead of `Console.draw.rect`.
    def mix_in_api(klass)
      return unless klass.is_a?(Class)
      return if klass.include?(Console::API)
      klass.include Console::API
    rescue
      nil
    end

    def defined?(name)
      @defs.key?(name.to_sym)
    end

    def names
      @defs.keys
    end

    # Per-scene state, created on first access.
    def store(name)
      root = @args.state.console_scenes ||= {}
      root[name.to_sym] ||= {}
    end

    # --- hooks ------------------------------------------------------------

    # Run a block whenever a scene is entered.
    def on_enter(name, &block)
      (@enter_hooks[name.to_sym] ||= []) << block
    end

    # Run a block whenever a scene is left.
    def on_leave(name, &block)
      (@leave_hooks[name.to_sym] ||= []) << block
    end

    # --- navigation -------------------------------------------------------

    def pending?
      !@pending.nil? || @pending_pop || @pending_clear
    end

    # Replace the entire stack with `name`.
    def goto(name)
      @pending = name.to_sym
      @pending_push = false
      @pending_pop = false
      @pending_clear = false
      name
    end

    # Push a scene on top of the current one.
    #
    #   pause:       (true)  freeze the scenes underneath, and the console's
    #                        timers/tweens. false keeps them updating.
    #   transparent: (false) render the scenes underneath first, so this one
    #                        draws over them.
    #   dim:         (0)     alpha 0-255 of a black wash drawn between the
    #                        scenes underneath and this one (transparent only).
    def push(name, options = {})
      @pending = name.to_sym
      @pending_push = true
      @pending_pop = false
      @pending_clear = false
      @pending_opts = options || {}
      name
    end

    def pop
      @pending_pop = true
      @pending_push = false
      @pending_clear = false
      nil
    end

    # Quit back to the first scene.
    def unwind
      @pending_clear = true
      @pending_pop = false
      nil
    end

    def depth
      @stack.size
    end

    def current_name
      @current
    end

    def instance
      @current_instance
    end

    def active?(name)
      @current == name.to_sym
    end

    def underneath?(name)
      return false if @stack.size < 2
      @stack[@stack.size - 2] == name.to_sym
    end

    # --- frame ------------------------------------------------------------

    # Update and draw the active scene, then commit any pending change. Called
    # once per frame by Console#tick.
    def run(draw_enabled = true)
      # A pending change (the first goto, or a new frame's request) is
      # committed up front so the scene activated here gets its update too.
      commit if pending?
      # A scene's `enter` may itself request a change.
      commit if pending?

      if @current
        # Non-pausing overlays let the scenes beneath them keep updating, and
        # transparent ones let them keep drawing. Both run bottom to top.
        top = @stack.size - 1
        (update_from..top).each do |i|
          as_scene(@stack[i]) { |inst, d| dispatch :update, inst, d }
        end
        if draw_enabled
          (draw_from..top).each do |i|
            name = @stack[i]
            dim = i > draw_from ? layer(name)[:dim].to_i : 0
            if dim > 0
              Console.draw.rect x: 0, y: 0, w: @args.grid.w, h: @args.grid.h,
                                color: :black, alpha: dim
            end
            as_scene(name) { |inst, d| dispatch :render, inst, d }
          end
        end
      end

      # Anything requested during update is applied now, so the next frame
      # runs the new scene and this one never sees a half-applied change.
      commit if pending?
    end

    # Draw the scene underneath the top one, dimmed. For overlays that render
    # the world themselves; `push_scene name, transparent: true` does this
    # automatically (and handles deeper stacks).
    def draw_below(draw_arg, alpha = 160)
      return if @stack.size < 2
      under = @stack[@stack.size - 2]
      d = @defs[under]
      return unless d
      inst = instance_for under, d
      # Pass d explicitly. Without it dispatch resolves @defs[@current] -- the
      # OVERLAY -- so a block-kind scene underneath would fail its
      # respond_to? check and silently not draw at all.
      dispatch :render, inst, d
      return unless alpha.to_i > 0
      draw_arg.rect x: 0, y: 0, w: @args.grid.w, h: @args.grid.h,
                     color: :black, alpha: alpha
    end

    # True when an overlay sits on top of the active scene.
    def overlay?
      @stack.size > 1
    end

    # True when a pausing overlay is on the stack. The scenes beneath it stop
    # updating, and the console freezes the schedulers to match. Without this,
    # world logic driven by `after`, `every`, tweens or `animate` keeps running
    # behind the overlay -- entities stop moving but keep dying, which is not a
    # pause. `push_scene name, pause: false` overlays do not count.
    def paused?
      update_from > 0
    end

    # The overlay options a scene was pushed with (defaults for the bottom).
    def layer(name)
      o = @layers[name.to_sym] || {}
      { pause: o.key?(:pause) ? o[:pause] : true,
        transparent: o[:transparent] ? true : false,
        dim: o[:dim] || 0 }
    end

    # Lowest stack index whose scene still updates this frame.
    def update_from
      i = @stack.size - 1
      i -= 1 while i > 0 && !layer(@stack[i])[:pause]
      i < 0 ? 0 : i
    end

    # Lowest stack index whose scene is drawn this frame.
    def draw_from
      i = @stack.size - 1
      i -= 1 while i > 0 && layer(@stack[i])[:transparent]
      i < 0 ? 0 : i
    end

    def dispatch(hook, inst, d = nil)
      d ||= @defs[@current]
      return unless d
      if d.kind == :class
        return unless inst.respond_to?(hook)
        return unless inst.method(hook).arity == 0
        inst.send hook
      elsif d.kind == :block
        return unless d.klass.key?(hook)
        d.klass[hook].call inst
      end
    end

    private

    # Run a block as if `name` were the active scene, so `current_scene`,
    # `scene_data` and friends resolve to it while a scene underneath an
    # overlay updates or renders.
    def as_scene(name)
      d = @defs[name]
      return unless d
      inst = instance_of name
      prev = @current
      prev_inst = @current_instance
      @current = name
      @current_instance = inst
      begin
        yield inst, d
      ensure
        @current = prev
        @current_instance = prev_inst
      end
    end

    def activate(name, resume = false)
      d = @defs[name]
      unless d
        puts "Console: scene #{name} is not defined; ignoring."
        return
      end
      @current_instance = instance_for name, d
      # Resuming must NOT re-run `enter`. Everything the scene was holding
      # lives on its instance, and re-entering would wipe it -- which is
      # precisely the difference between pop (resume) and goto (restart).
      unless resume
        dispatch :enter, @current_instance
        (@enter_hooks[name.to_sym] || []).each { |h| h.call @current_instance }
      end
      # A scene may immediately request another change (common for routing
      # guards), so give it a chance before drawing anything.
      commit if pending?
    end

    def leave(name, inst = @current_instance)
      return if name.nil?
      d = @defs[name]
      dispatch :leave, inst, d if d
      (@leave_hooks[name.to_sym] || []).each { |h| h.call inst }
      @current_instance = nil if inst.equal?(@current_instance)
    end

    # The live instance for a scene on the stack: the active one, or the cached
    # instance of a scene paused underneath an overlay.
    def instance_of(name)
      return @current_instance if name == @current
      d = @defs[name]
      return nil unless d
      d.kind == :block ? d.klass : (@instances || {})[name]
    end

    def instance_for(name, d)
      case d.kind
      when :class
        # Cached per scene name. A scene that was pushed over has to survive the
        # trip, because pop_scene RESUMES it: building a fresh instance here
        # would hand the resumed scene nil state, which is what made
        # draw_below crash and left pop_scene rendering a frozen screen.
        # `goto` clears this cache, so a hard restart still gets a clean slate.
        @instances ||= {}
        @instances[name] ||= d.klass.new
      when :block
        d.klass
      else
        nil
      end
    end

    def commit
      if @pending_clear
        @pending_clear = false
        return if @stack.size <= 1
        # Leave every overlay, top first, then resume the bottom scene.
        while @stack.size > 1
          top = @stack.pop
          @layers.delete top
          leave top, instance_of(top)
        end
        @current = @stack.last
        activate @current, true
        return
      end

      if @pending_pop
        @pending_pop = false
        return if @stack.size <= 1
        top = @stack.pop
        @layers.delete top
        leave top
        @current = @stack.last
        # Resume, do not restart: re-activate the scene underneath WITHOUT
        # running `enter`. Setting @current_instance = nil and returning here is
        # what froze the screen -- every later dispatch then hit
        # `return unless inst.respond_to?(hook)` on nil.
        activate @current, true
        return
      end

      return if @pending.nil?
      name = @pending
      @pending = nil

      if @pending_push
        @pending_push = false
        return if @stack.include?(name)
        @stack.push name
        @layers[name] = @pending_opts
      else
        # `goto` replaces the stack: leave every scene on it, top first, so a
        # goto out of a pause overlay also runs the paused scene's `leave`.
        @stack.reverse.each { |n| leave n, instance_of(n) }
        @stack = [name]
        @layers = {}
        # ...and drop every cached scene instance. `goto` is a hard restart,
        # so the destination must be entered fresh -- unlike pop, which resumes.
        @instances = {}
      end

      @history.push @current
      @history = @history.last(32)
      @current = @stack.last
      @current_instance = nil
      activate @current
    end
  end
end