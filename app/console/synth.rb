# Console::Synth -- sound effects with no sound files.
#
# DragonRuby plays a raw sample array as easily as a .wav
# (`input: [channels, rate, samples]`), so a retro sfx is just a waveform, a
# pitch and an envelope, computed once and cached.
#
#   synth :coin                                   # a preset
#   synth :jump, pitch: 1.2, gain: 0.5            # playback options
#   synth :shoot, length: 0.3                     # a preset, overridden
#   synth wave: :sine, freq: 440, to: 880, length: 0.2
#   synth freq: [523, 659, 784]                   # an arpeggio
#   sfx :hit          # no hit.wav registered? plays the :hit preset instead
#
# Waves: :square (with duty:), :sine, :saw, :triangle, :noise. For :noise,
# freq is how often the noise changes, so a low freq is a rumble.
module Console
  module Synth
    extend self

    RATE = 22050

    DEFAULTS = { wave: :square, freq: 440.0, length: 0.15, attack: 0.005,
                 volume: 0.4, duty: 0.5 }

    # Overrides of DEFAULTS. A cart may add or alias its own:
    #   Console::Synth::PRESETS[:zap] = { wave: :saw, freq: 2000, to: 100 }
    PRESETS = {
      blip: { freq: 880, length: 0.05 },
      click: { wave: :triangle, freq: 1800, length: 0.03 },
      coin: { freq: [988, 1319], length: 0.25 },
      jump: { freq: 300, to: 600, length: 0.18, duty: 0.25 },
      land: { wave: :noise, freq: 800, to: 200, length: 0.08 },
      shoot: { wave: :saw, freq: 1200, to: 200, length: 0.15 },
      hit: { wave: :noise, freq: 3000, to: 1000, length: 0.1 },
      hurt: { wave: :saw, freq: 400, to: 100, length: 0.25 },
      explode: { wave: :noise, freq: 1000, to: 60, length: 0.6, volume: 0.6 },
      powerup: { freq: [523, 659, 784, 1047], length: 0.4 },
      gameover: { wave: :triangle, freq: [392, 330, 262, 196], length: 1.0,
                  volume: 0.6 }
    }

    # The mono sample array for a sound. `freq:` is Hz, or a list of notes
    # played in equal slices; `to:` slides the pitch over the whole sound.
    # The envelope is a short attack then a linear fade to silence.
    def samples(options = {})
      key = options.to_s
      @cache ||= {}
      return @cache[key] if @cache[key]
      # ponytail: flush-all cache, bounded so per-call random params cannot leak.
      @cache = {} if @cache.size > 64
      @cache[key] = build(DEFAULTS.merge(options))
    end

    private

    # Kept incremental -- no per-sample division or lookups -- because mruby
    # pays for every operation here, 22050 times a second of sound.
    def build(o)
      notes = o[:freq].is_a?(Array) ? o[:freq] : [o[:freq]]
      attack = (o[:attack] * RATE).to_i
      attack = 1 if attack < 1
      n = (o[:length] * RATE).to_i
      n = attack + 1 if n <= attack
      inv_rate = 1.0 / RATE
      bend = 0.0
      bend_step = o[:to] ? (o[:to] - notes[0]).to_f / n : 0.0
      slice = n.to_f / notes.size
      note_i = 0
      note = notes[0].to_f
      next_note = slice
      env = 0.0
      rise = 1.0 / attack
      fall = 1.0 / (n - attack)
      wave = o[:wave]
      duty = o[:duty]
      vol = o[:volume]
      tau = 2 * Math::PI
      phase = 0.0
      held = 0.0
      out = []
      i = 0
      while i < n
        if i >= next_note
          note_i += 1 if note_i < notes.size - 1
          note = notes[note_i].to_f
          next_note += slice
        end
        phase += (note + bend) * inv_rate
        bend += bend_step
        if phase >= 1.0
          phase -= phase.floor
          held = (rand * 2) - 1
        end
        v = if wave == :square then phase < duty ? vol : -vol
            elsif wave == :noise then held * vol
            elsif wave == :saw then ((2 * phase) - 1) * vol
            elsif wave == :triangle then ((4 * (phase - 0.5).abs) - 1) * vol
            else Math.sin(tau * phase) * vol
            end
        out << v * env
        env += i < attack ? rise : -fall
        i += 1
      end
      out
    end
  end
end
