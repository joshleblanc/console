# Console::CartLoader -- finds a cart, requires it, and starts the console.
#
# A "cart" is a directory under carts/ that defines one module (or class)
# implementing the cart contract:
#
#   carts/space/
#     app/space.rb        the cart: one module/class named after the directory
#     sprites/            its own art
#     sounds/  maps/  data/
#
# Only the selected cart is ever required, so a cart is genuinely a standalone
# program: nothing else in carts/ is parsed at runtime, so a broken cart can
# never stop the console from booting, and two carts can both have a
# `sprites/hero.png` without seeing each other's.
#
# The contract is intentionally tiny. All of these hooks are optional:
#
#   def self.assets    # { sprites: {...}, sounds: {...}, music: {...} }
#   def setup         # once, at boot
#   def update        # every frame (when the cart defines no scenes)
#   def render        # every frame, always last: use it for a HUD
#
# And it may define scenes instead of `update`:
#
#   scene :title, TitleScene
#
# Every API method in Console::API is available as a bare call inside a cart.
# Paths a cart writes are relative to its own directory -- `sprites/hero.png`
# means carts/space/sprites/hero.png -- which Console::Assets resolves.
module Console
  class CartLoader
    CARTS_DIR = 'carts'
    DEFAULT_CART = 'selftest'

    attr_reader :args, :errors

    def initialize(args)
      @args = args
      @errors = []
      @selected = nil
      @cart = nil
      @pinned = nil
    end

    def cli
      @cli ||= DR.cli_arguments
    end

    # Pin the loader to exactly one cart.
    #
    # This is how a published single-cart build boots: ./publish-cart stages a
    # directory holding one cart file and an entry point that pins it, so the
    # cart cannot be swapped at runtime.
    #
    # A pin outranks --cart and $CART. In a packaged build there is no terminal
    # to type at, and the whole point is that what you shipped is what runs.
    def pin(name)
      @pinned = name.to_s
      self
    end

    def pinned?
      !@pinned.nil? && !@pinned.to_s.empty?
    end

    def pinned_name
      @pinned
    end

    # --- discovery --------------------------------------------------------

    # A cart is a directory that holds an entry file of the same name.
    def cart_dir(name)
      "#{CARTS_DIR}/#{name}"
    end

    def cart_entry(name)
      "#{cart_dir(name)}/app/#{name}.rb"
    end

    # Cart names, sorted. Only directories with an entry file count, so a
    # half-created cart or a stray README in carts/ is simply not a cart.
    def available
      return [] unless DR.stat_file(CARTS_DIR)
      names = []
      DR.list_files(CARTS_DIR).each do |entry|
        info = DR.stat_file "#{CARTS_DIR}/#{entry}"
        next unless info
        next unless info[:file_type] == :directory
        next unless DR.stat_file(cart_entry(entry))
        names << entry
      end
      names.sort
    end

    # Explicit wins, then the env var, then a deterministic fallback.
    #
    # A pin beats everything: a published build is pinned, and there is nothing
    # sensible for it to fall back *to*.
    def requested_name
      return @pinned if pinned?
      name = cli[:cart] if cli.key? :cart
      name = DR.getenv('CART') if name.nil? || name.to_s.empty?
      name = DEFAULT_CART if name.nil? || name.to_s.empty?
      name.to_s
    end

    def selected_name
      @selected
    end

    # --- running ----------------------------------------------------------

    def run
      handle_list if switch?(:list)

      name = requested_name
      available_names = available

      unless available_names.include?(name)
        # A pinned cart that is missing is a packaging bug, not a typo to paper
        # over. Booting some other cart here would ship a game that is not the
        # one that was asked for, so fail loudly instead.
        if pinned?
          abort_boot "pinned cart '#{name}' is not present in #{CARTS_DIR}"
          return nil
        end

        fallback = available_names.include?(DEFAULT_CART) ? DEFAULT_CART : available_names.first
        if fallback.nil?
          abort_boot "no carts found in #{CARTS_DIR}"
          return nil
        end
        puts "[console] cart '#{name}' not found; booting '#{fallback}' instead."
        name = fallback
      end

      @selected = name
      path = cart_entry name

      # Scope assets before anything is required. A cart may declare its assets
      # at load time, and it must already be looking at its own directory.
      Console::Assets.boot cart_dir(name)

      begin
        require path
        require_cart_files name
      rescue => e
        abort_boot "could not require #{path}: #{e.class}: #{e.message}"
        return nil
      end

      cart = resolve_cart_module name
      if cart.nil?
        abort_boot "#{path} did not define a cart module"
        return nil
      end

      instance = instantiate cart
      return nil if instance.nil?
      @cart = instance

      # Boot first, then honour switches. The self test asserts against live
      # subsystems, so it can only run once the console is fully wired.
      Console.boot @args, instance, name
      apply_switches

      # --selftest implies the selftest cart, whichever cart booted. A pinned
      # build ships exactly one cart, so if that cart is not the selftest there
      # is nothing to require -- and requiring a missing file would crash the
      # published build rather than report a clean skip.
      if switch?(:selftest) && !pinned?
        summary = run_selftest
        puts Console::Test.summary_line(summary)
        quit_now summary[:status] == 'PASS'
      end

      cart
    end

    # Require the rest of the cart's own top-level code files.
    #
    # A cart is allowed to be more than one file -- that is what app/ is for --
    # and the entry file is always required first, so a cart can define things
    # its siblings reference at load time. Only this cart's directory is read,
    # which is the property that keeps one broken cart from taking the console
    # down with it. Sub-directories are the cart's to require itself.
    def require_cart_files(name)
      dir = "#{cart_dir(name)}/app"
      return unless DR.stat_file dir
      entry = cart_entry name
      extra = []
      DR.list_files(dir).each do |file|
        next unless file.end_with? '.rb'
        path = "#{dir}/#{file}"
        next if path == entry
        extra << path
      end
      extra.sort.each { |p| require p }
    end

    # Run the built-in suites.
    #
    # The suites assert against asset files the selftest cart owns, so the
    # asset scope moves to that cart even when a different one booted: a test
    # that resolved a fixture against whichever cart happened to boot would
    # quietly assert nothing useful.
    def run_selftest
      Console::Assets.boot cart_dir('selftest')
      require cart_entry('selftest')
      Console::Test.run @args
    end

    # A cart file may define a Class (hooks as instance methods) or a Module
    # (hooks as singleton methods). Classes are instantiated so that carts can
    # hold per-run state.
    def instantiate(cart)
      return cart unless cart.is_a?(Class)
      cart.new
    rescue => e
      abort_boot "could not construct #{cart}: #{e.class}: #{e.message}"
      nil
    end

    # A cart file may define either a module or a class named after itself.
    def resolve_cart_module(name)
      candidates = [name, Console::Str.camel(name)]
      candidates += ["Cart#{candidates[1]}"]
      candidates.each do |const|
        begin
          value = Object.const_get const
          return value if value.respond_to?(:setup) || value.is_a?(Module)
        rescue
          next
        end
      end
      nil
    end

    def apply_switches
      Console.show_hud = true if switch?(:hud)

      ticks = cli[:ticks]
      Console.quit_after = ticks.to_i if ticks && !ticks.to_s.empty?

      # --scene <name> jumps straight into a scene. Handy while iterating on
      # gameplay: you do not have to play through the title screen every time.
      scene = cli[:scene]
      if scene && !scene.to_s.empty?
        Console.goto_scene scene
      end

      shot = cli[:shot]
      if shot && !shot.to_s.empty?
        at = cli[:shot_at]
        at = at.to_i unless at.nil?
        # DragonRuby allots a frame to actually encode the PNG, so a screenshot
        # requested on the same tick as the quit would be lost. Leave it a few
        # frames of runway.
        at = (Console.quit_after - 3) if at.nil? && Console.quit_after
        Console.screenshot shot, at
      end
    end

    # --- switches ---------------------------------------------------------

    def handle_list
      names = available
      puts ''
      puts 'Available carts:'
      names.each do |n|
        mark = n == DEFAULT_CART ? ' (default)' : ''
        title = cart_title n
        puts "  #{n}#{mark}#{title ? "  -- #{title}" : ''}"
      end
      puts ''
      puts "Run one with:  ./run --cart <name>"
      quit_now
    end

    # Read a cart's title without requiring it: grep the source.
    def cart_title(name)
      info = DR.stat_file cart_entry(name)
      return nil unless info
      source = DR.read_file cart_entry(name)
      return nil unless source
      Console::Str.quoted_value_after(source, 'TITLE')
    end

    def handle_test
      summary = run_selftest
      puts Console::Test.summary_line(summary)
      quit_now(summary[:status] == 'PASS')
    end

    def abort_boot(message)
      puts "[console] BOOT ERROR: #{message}"
      @errors << message
      DR.request_quit
    end

    def quit_now(ok = true)
      DR.request_quit
      @quit_status = ok ? 0 : 1
    end

    # Is a switch present?
    #
    # DR.cli_arguments stores a bare switch (`--list`) as a key with a nil
    # value, which is indistinguishable from an absent key by lookup alone --
    # so the key's presence is what counts, and only an explicit falsey value
    # turns it off (`--list=false`).
    def switch?(key)
      return false unless cli.key? key
      value = cli[key]
      return true if value.nil?
      v = value.to_s.downcase
      !(v == 'false' || v == '0' || v == 'no')
    end
  end
end