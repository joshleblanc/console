# Console::CartLoader -- finds a cart, requires it, and starts the console.
#
# A "cart" is a directory that defines one module (or class) implementing the
# cart contract:
#
#   carts/space/
#     app/space.rb        the cart: one module/class named after the directory
#     sprites/            its own art
#     sounds/  maps/  data/
#
# Carts are read from two directories: carts/, which is yours and is not
# tracked by the console's repository, and samples/, which ships with the
# console. Your carts are looked up first, so a cart of yours shadows a sample
# of the same name, and a fresh checkout still has the samples to boot.
#
# Only the selected cart is ever required, so a cart is genuinely a standalone
# program: nothing else in the gallery is parsed at runtime, so a broken cart
# can never stop the console from booting, and two carts can both have a
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
    SAMPLES_DIR = 'samples'
    DEFAULT_CART = 'selftest'

    # Where a bare cart name is looked up, in order. Your own carts come
    # first: a cart of yours shadows a sample of the same name, which is how
    # you take a sample over (copy it into carts/) without renaming it.
    GALLERY_DIRS = [CARTS_DIR, SAMPLES_DIR].freeze

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
    # This is how a published single-cart build boots: ./bin/publish-cart stages a
    # directory holding one cart and an entry point that pins it, so the cart
    # cannot be swapped at runtime.
    #
    # The pin accepts a name or a path, exactly like --cart does, so a staged
    # build pins 'carts/space' and keeps working if the cart is ever moved.
    #
    # A pin outranks --cart and $CART. In a packaged build there is no terminal
    # to type at, and the whole point is that what you shipped is what runs.
    def pin(target)
      @pinned = target.to_s
      self
    end

    def pinned?
      !@pinned.nil? && !@pinned.to_s.empty?
    end

    def pinned_name
      @pinned
    end

    # --- discovery --------------------------------------------------------

    # Turn whatever was asked for into a cart directory.
    #
    # A bare name means the gallery: 'space' is carts/space, or samples/space
    # when you have no cart of that name. Anything with a path separator is
    # taken as a path, which is what lets a cart live in games/ or demos/
    # instead of carts/ without the console caring.
    def cart_dir(target)
<<<<<<< HEAD
      s = Console::Str.chomp_slash Console::Str.backslash_to_slash(target)
=======
      # Normalise the separator FIRST. A Windows target arrives as carts\space
      # (the README documents that form), and the test below only recognises
      # '/', so a backslash target used to fall through as a bare NAME and
      # resolve to carts/carts\space -- which does not exist, so the console
      # silently booted the default cart instead of the one asked for.
      s = Console::Str.chomp_slash target.to_s.gsub('\\', '/')
>>>>>>> b45682af0c0f6bec3c421a42209ec7c0907a54f2
      return nil if s.empty?
      return s if s.include? '/'
      gallery_dir s
    end

    # Where a bare cart name lives: carts/ first, then samples/.
    #
    # The last resort is carts/<name> even when nothing is there, so a name
    # that matches nothing still reports the path the user expected -- and
    # the fallback in run can say what it looked for.
    def gallery_dir(name)
      GALLERY_DIRS.each do |dir|
        candidate = "#{dir}/#{name}"
        return candidate if cart? candidate
      end
      "#{CARTS_DIR}/#{name}"
    end

    # The cart's name is the last segment of its directory, which is also the
    # module name resolve_cart_module looks for.
    def cart_name(dir)
      Console::Str.basename dir
    end

    # A cart's entry file.
    #
    # app/main.rb is preferred -- "the entry point" means the same thing here as
    # it does at the console root, and it drops the name stutter. app/<name>.rb
    # is still accepted so a cart written the old way keeps working.
    def cart_entry(dir)
      base = "#{dir}/app"
      main = "#{base}/main.rb"
      return main if DR.stat_file main
      "#{base}/#{cart_name(dir)}.rb"
    end

    # Is this a bootable cart?
    def cart?(dir)
      return false if dir.nil?
      !DR.stat_file(cart_entry(dir)).nil?
    end

    # Cart names in the gallery, sorted.
    #
    # Both directories count: your carts in carts/ and the samples the console
    # ships in samples/. A name is listed once even when it is in both, and
    # the one in carts/ is the one that runs -- so taking a sample over by
    # copying it into carts/ does not double it up in the list.
    #
    # Only directories with an entry file count, so a half-created cart or a
    # stray README in carts/ is simply not a cart.
    def available
      names = []
      GALLERY_DIRS.each do |dir|
        next unless DR.stat_file(dir)
        DR.list_files(dir).each do |entry|
          info = DR.stat_file "#{dir}/#{entry}"
          next unless info
          next unless info[:file_type] == :directory
          next unless cart?("#{dir}/#{entry}")
          names << entry unless names.include?(entry)
        end
      end
      names.sort
    end

    # Is this cart one of the samples rather than one of your own?
    def sample?(name)
      dir = cart_dir name
      !dir.nil? && dir.start_with?("#{SAMPLES_DIR}/")
    end

    # Explicit wins, then the env var, then a deterministic fallback.
    #
    # A pin beats everything: a published build is pinned, and there is nothing
    # sensible for it to fall back *to*.
    #
    # The value is whatever was asked for -- a bare name or a path -- and it is
    # left that way so callers can report exactly what the user typed. Use
    # requested_dir to get the directory it resolves to.
    def requested_name
      return @pinned if pinned?
      name = cli[:cart] if cli.key? :cart
      name = DR.getenv('CART') if name.nil? || name.to_s.empty?
      name = DEFAULT_CART if name.nil? || name.to_s.empty?
      name.to_s
    end

    # The directory the requested target resolves to.
    def requested_dir
      cart_dir requested_name
    end

    def selected_name
      @selected
    end

    # --- running ----------------------------------------------------------

    def run
      if switch?(:list)
        handle_list
        return nil
      end

      target = requested_name
      dir = cart_dir target

      unless cart? dir
        # A pinned cart that is missing is a packaging bug, not a typo to paper
        # over. Booting some other cart here would ship a game that is not the
        # one that was asked for, so fail loudly instead.
        if pinned?
          abort_boot "pinned cart '#{target}' is not a cart directory (looked for #{cart_entry(dir)})"
          return nil
        end

        available_names = available
        fallback = available_names.include?(DEFAULT_CART) ? DEFAULT_CART : available_names.first
        if fallback.nil?
          abort_boot "no carts found in #{CARTS_DIR} or #{SAMPLES_DIR}"
          return nil
        end
        # DragonRuby resolves every file against the game directory and will not
        # stat a path that escapes it, so naming a cart outside this console
        # fails however it is spelled. Say so, rather than implying a typo.
        outside = dir.to_s.start_with?('/') || dir.to_s.start_with?('..')
        hint = outside ? ' (a cart has to sit inside the console)' : ''
        puts "[console] cart '#{target}' not found#{hint}; booting '#{fallback}' instead."
        target = fallback
        dir = cart_dir target
      end

      name = cart_name dir
      @selected = name
      path = cart_entry dir

      # Scope assets before anything is required. A cart may declare its assets
      # at load time, and it must already be looking at its own directory.
      Console::Assets.boot dir

      begin
        require path
        require_cart_files dir, path
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
    def require_cart_files(cart, entry)
      dir = "#{cart}/app"
      return unless DR.stat_file dir
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
      dir = cart_dir 'selftest'
      Console::Assets.boot dir
      require cart_entry(dir)
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
        mark += ' (sample)' if sample?(n)
        title = cart_title cart_dir(n)
        puts "  #{n}#{mark}#{title ? "  -- #{title}" : ''}"
      end
      puts ''
      puts "Run one with:  ./bin/run <name>"
      puts "Your own carts live in #{CARTS_DIR}/; the samples in #{SAMPLES_DIR}/ ship with the console."
      quit_now
    end

    # Read a cart's title without requiring it: grep the source.
    def cart_title(dir)
      info = DR.stat_file cart_entry(dir)
      return nil unless info
      source = DR.read_file cart_entry(dir)
      return nil unless source
      Console::Str.quoted_value_after(source, 'TITLE')
    end

    def abort_boot(message)
      puts "[console] BOOT ERROR: #{message}"
      @errors << message
      DR.request_quit
    end

    def quit_now(_ok = true)
      DR.request_quit
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