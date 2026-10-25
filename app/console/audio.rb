# Console::Audio -- sound effects and music.
#
# DragonRuby has no `play` method: you write into `args.audio` keyed by a symbol
# of your choosing, or push a one-shot into `args.outputs.sounds`. This module
# wraps both so a cart says `sfx(:jump)` and never touches a file path.
#
#   sfx :jump
#   sfx :hit, pitch: 0.8, gain: 0.6
#   music :title
#   music_gain 0.4
#   stop_music
#
# Music is tracked under one stable key, so calling `music` again crossfades by
# replacement instead of stacking loops. SFX are one-shots and self-clean.
module Console
  class Audio
    SFX_KEY_PREFIX = 'sfx_'
    MUSIC_KEY = 'console_music'

    attr_reader :registry
    attr_accessor :master_gain

    def initialize(args)
      @args = args
      @registry = {}
      @master_gain = 1.0
      @current_music = nil
      @current_music_name = nil
      @muted = false
      @missing = []
    end

    def args
      @args
    end

    # --- registration -----------------------------------------------------

    # teach the console where a sound lives
    #
    # The path is resolved against the booted cart, so `register :jump,
    # 'sounds/jump.wav'` inside a cart means that cart's own file.
    def register(name, path)
      @registry[name.to_s] = Assets.resolve path
    end

    def register_all(hash)
      hash.each { |k, v| register k, v }
    end

    def music_library(hash)
      hash.each { |k, v| register "music_#{k}", v }
    end

    def resolve(name)
      key = name.to_s
      @registry[key] ||
        @registry["music_#{key}"] ||
        @registry["sfx_#{key}"] ||
        begin
          @missing << key unless @missing.include?(key)
          nil
        end
    end

    def missing_names
      @missing.dup
    end

    # --- sfx --------------------------------------------------------------

    # Play a one-shot. gain and pitch are floats (DragonRuby warns otherwise).
    # The master gain (set by music_gain) scales every sfx, given a gain or not.
    def sfx(name, options = {})
      return nil if @muted
      path = resolve name
      return nil unless path
      prim = { path: path,
               gain: (options[:gain] || 1.0).to_f * @master_gain }
      pitch = options[:pitch]
      prim[:pitch] = pitch.to_f if pitch
      @args.outputs.sounds << prim
      prim
    end

    # --- music ------------------------------------------------------------

    # Start (or swap) the looping music track. Repeating the same name is a
    # no-op, so this is safe to call every frame.
    def music(name, options = {})
      return nil if @muted
      return @current_music_name if name == @current_music_name
      stop_music
      path = resolve(name)
      unless path
        @current_music_name = name
        return nil
      end
      entry = {
        input: path,
        looping: true,
        gain: (options[:gain] || 1.0).to_f * @master_gain,
        pitch: (options[:pitch] || 1.0).to_f
      }
      @args.audio[MUSIC_KEY] = entry
      @current_music = entry
      @current_music_name = name
      @track_gain = (options[:gain] || 1.0).to_f
      entry
    end

    def stop_music
      @args.audio[MUSIC_KEY] = nil
      @current_music = nil
      @current_music_name = nil
      nil
    end

    def music_name
      @current_music_name
    end

    def music_playing?
      !@current_music_name.nil?
    end

    # Master volume, 0.0..1.0. Scales the playing track in place (it keeps
    # playing from where it was) and every later sfx and track.
    def music_gain(value)
      if value.nil?
        return @current_music ? @current_music[:gain] : nil
      end
      @master_gain = value.to_f
      apply_track_gain
      @master_gain
    end

    # Volume of the currently playing track only, before the master gain.
    def track_gain(value)
      return nil unless @current_music
      return @track_gain if value.nil?
      @track_gain = value.to_f
      apply_track_gain
      @track_gain
    end

    # --- global -----------------------------------------------------------

    def mute
      @muted = true
      stop_music
      @args.audio.volume = 0.0
      true
    end

    def unmute
      @muted = false
      @args.audio.volume = 1.0
      true
    end

    def muted?
      @muted
    end

    def toggle_mute
      @muted ? unmute : mute
    end

    # Stop everything this console owns, leaving other audio alone.
    def stop_all
      stop_music
    end

    private

    # DragonRuby reads args.audio entries every frame, so changing :gain on the
    # live entry adjusts the volume without restarting the track.
    def apply_track_gain
      return unless @current_music
      @current_music[:gain] = (@track_gain || 1.0) * @master_gain
      live = @args.audio[MUSIC_KEY]
      live[:gain] = @current_music[:gain] if live && !live.equal?(@current_music)
    end
  end
end