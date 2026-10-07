# Cart: arcade
#
# A complete, playable MVP: title screen, waves of enemies, shooting,
# scoring, a pause overlay and a game-over screen. It is here to show that the
# surface is big enough for a real game while staying small enough to read.
#
#   ./bin/run --cart arcade
#
# Controls: arrows / WASD / left stick to move, space / gamepad A to shoot,
# ESC to pause. Every action goes through `input`, so the same code serves
# keyboard, gamepad and touch.
TITLE = 'arcade'

class Arcade
  # The playfield. x/y included because the camera clamps against it.
  WORLD = { x: 0, y: 0, w: 1600, h: 900 }
  PLAYER_SPEED = 5.0
  BULLET_SPEED = 9.0

  def self.assets
    # Only the ship has real art, and it lives in this cart's own
    # sprites/hero/. Everything else is generated below, which is the point: a
    # cart is playable before any art exists.
    { sprites: { ship: 'sprites/hero/idle/0.png' } }
  end

  def setup
    # Generate anything the art folder does not have, so the cart always runs.
    auto_sprite :spark, 8, 8, :accent2, :circle
    auto_sprite :enemy_block, 24, 24, :warn, :frame
    auto_sprite :tracer, 6, 14, :accent, :stripes

    scene :title, TitleScene
    scene :play, PlayScene
    scene :pause, PauseScene
    scene :gameover, GameOverScene
    goto :title
  end

  # The cart's render hook runs after whichever scene drew, so it is the place
  # for a HUD that persists across scenes.
  def render
    ui.hud
    draw.text 'F1 hud', x: screen[:w] - 20, y: top(16), anchor_x: 1.0,
              size_enum: -3, color: :muted
  end

  # ---------------------------------------------------------------- scenes

  class TitleScene
    def enter
      Console.scenes.store(:title)[:t] = 0
      music :title
    end

    def update
      d = Console.scenes.store :title
      d[:t] = (d[:t] || 0) + 1
      if input.pressed?(:accept) || input.pressed?(:up)
        goto :play
      end
    end

    def render
      card = Console.ui.card w: 520, h: 320
      Console.draw.text 'ARCADE',
                        x: card[:x] + (card[:w] / 2.0),
                        y: card[:y] + card[:h] - 90,
                        anchor_x: 0.5, size_px: 46, color: :accent
      Console.draw.text 'a cart in about a hundred lines',
                        x: card[:x] + (card[:w] / 2.0),
                        y: card[:y] + card[:h] - 130,
                        anchor_x: 0.5, color: :muted

      Console.draw.sprite path: Console.sprite(:ship),
                          x: card[:x] + (card[:w] / 2.0),
                          y: card[:y] + 110,
                          anchor_x: 0.5, w: 32, h: 32

      Console.ui.button x: card[:x] + 60, y: card[:y] + 50, w: 400, h: 56,
                        text: 'PRESS SPACE / A TO START', id: 'start'
    end
  end

  class PlayScene
    def enter
      Console.entities.clear
      Console.tweens.clear
      Console.anim.stop_all
      Console.camera.follow nil
      Console.camera.bounds = nil

      d = scene_data
      d[:score] = 0
      d[:wave] = 1
      d[:lives] = 3
      d[:shot_cooldown] = 0

      @ship = spawn :ship, kind: :hero, x: 800, y: 120, w: 28, h: 28,
                       sprite: :ship
      animate @ship, :idle, fps: 8
      Console.camera.follow @ship

      # A wave spawner that reschedules itself -- no coroutines needed.
      every 90, immediate: true do
        next_wave
      end

      music :game
    end

    def update
      d = scene_data

      camera.update
      move_player
      shoot
      advance_waves
      move_entities
      collisions
      cull

      d[:score] += 1 if input.held?(:action_1)
    end

    def render
      background :panel_d
      # World first, inside the camera transform.
      camera.bounds = WORLD
      camera.apply do
        each_entity do |e|
          draw_entity e
        end
        draw_walls
      end

      # Then the HUD, screen-locked.
      hud
    end

    def leave
      stop_music
      Console.entities.clear
      Console.anim.stop_all
      Console.tweens.clear
    end

    private

    def move_player
      p = input.axis_vector
      speed = PLAYER_SPEED
      @ship[:x] = (@ship[:x] + (p[:x] * speed)).clamp(0, WORLD[:w] - @ship[:w])
      @ship[:y] = (@ship[:y] + (p[:y] * speed)).clamp(0, WORLD[:h] - @ship[:h])
      animate @ship, :run, fps: 14 if (p[:x] != 0 || p[:y] != 0)
      animate @ship, :idle, fps: 8 if p[:x] == 0 && p[:y] == 0
    end

    def shoot
      d = scene_data
      d[:shot_cooldown] -= 1
      return unless input.pressed?(:accept) || input.pressed?(:action_2)
      return if d[:shot_cooldown] > 0
      d[:shot_cooldown] = 8
      spawn :bullet, kind: :bullet, x: @ship[:x] + 11, y: @ship[:y] + 34,
                    w: 6, h: 14, sprite: :tracer, vx: 0, vy: BULLET_SPEED
      sfx :shoot
    end

    def next_wave
      d = scene_data
      d[:wave] = (d[:wave] || 1) + 1 unless d[:wave_started]
      d[:wave_started] = true
      count = 3 + (d[:wave] * 2)
      count = 40 if count > 40
      count.times do |i|
        after(i * 14) do
          spawn_enemy
        end
      end
      every 90 do
        next_wave
      end
      sfx :wave
    end

    def spawn_enemy
      w = 24
      h = 24
      e = spawn :enemy,
                kind: :enemy,
                x: rand_int(40, WORLD[:w] - 80),
                y: WORLD[:h] + 40,
                w: w, h: h,
                sprite: :enemy_block,
                vx: rand_between(-1.5, 1.5),
                vy: -rand_between(1.4, 3.0),
                hp: 1,
                tint: chance(0.3) ? :warn : :accent2
      animate e, :hit, fps: 12, repeat: false
      after 240 do
        despawn e if entities_of(:enemy).include?(e)
      end
    end

    def advance_waves
      # Nothing to do per frame yet; kept as the hook for difficulty ramps.
    end

    def move_entities
      each_entity do |e|
        next if e[:kind] == :hero
        move e, vx: (e[:vx] || 0), vy: (e[:vy] || 0)
      end
    end

    def collisions
      each_entity(:bullet) do |b|
        hit = colliding(b, :enemy).first
        next unless hit
        despawn b
        hit[:hp] -= 1
        sfx :hit
        camera.shake 4, 8
        burst hit[:x], hit[:y], :warn, 6
        if hit[:hp] <= 0
          despawn hit
          stop_anim hit
          scene_data[:score] += 10
          sfx :explode
          burst hit[:x], hit[:y], :accent2, 14
        end
      end

      each_entity(:enemy) do |e|
        next unless e.intersect_rect?(@ship)
        despawn e
        damage_player
      end
    end

    def damage_player
      d = scene_data
      d[:lives] -= 1
      camera.shake 10, 16
      sfx :hurt
      @ship[:alpha] = 60
      tween @ship, :alpha, to: 255, in: 20, ease: :out
      if d[:lives] <= 0
        goto :gameover
      end
    end

    def burst(x, y, color, count)
      count.times do
        spawn :spark, kind: :spark,
                      x: x, y: y, w: 8, h: 8, sprite: :spark,
                      vx: rand_between(-3, 3), vy: rand_between(-3, 3),
                      tint: color, life: 30
      end
    end

    def cull
      despawn_if do |e|
        (e[:kind] == :spark && (e[:life] -= 1) <= 0) ||
          (e[:kind] != :hero && (e[:x] < -60 || e[:x] > WORLD[:w] + 60 ||
                                    e[:y] < -60 || e[:y] > WORLD[:h] + 60))
      end
    end

    def draw_walls
      draw.rect x: 0, y: 0, w: WORLD[:w], h: 24, color: :panel
      draw.rect x: 0, y: WORLD[:h] - 24, w: WORLD[:w], h: 24, color: :panel
      draw.rect x: 0, y: 0, w: 24, h: WORLD[:h], color: :panel
      draw.rect x: WORLD[:w] - 24, y: 0, w: 24, h: WORLD[:h], color: :panel
    end

    def hud
      d = scene_data
      draw.within strip(0, 56) do
        draw.rect place: { x: 0, y: 0, w: 1, h: 1 }, color: :black, alpha: 160
        draw.text "SCORE #{d[:score]}",
                  place: { x: 0.02, y: 0.5, anchor_y: 0.5 }, color: :text
        draw.text "WAVE #{d[:wave]}",
                  place: { x: 0.5, y: 0.5, anchor_x: 0.5, anchor_y: 0.5 },
                  color: :muted
      end
      ui.pips x: 20, top: 66, w: 140, value: d[:lives], max: 3,
              color: :good, h: 12
      if input.pressed?(:cancel)
        push_scene :pause
      end
    end
  end

  class PauseScene
    def enter
      sfx :pause
    end

    def update
      return if input.pressed?(:cancel)
      return unless input.pressed?(:up) || input.pressed?(:down) ||
                    input.pressed?(:accept)
      pop_scene
    end

    def render
      # Re-draw the world underneath, dimmed, so the pause screen reads as an
      # overlay rather than a separate place.
      Console.scenes.draw_below Console.draw
      card = Console.ui.card w: 360, h: 220
      Console.draw.text 'PAUSED',
                        x: card[:x] + (card[:w] / 2.0),
                        y: card[:y] + card[:h] - 70,
                        anchor_x: 0.5, size_px: 34, color: :accent
      Console.ui.menu x: card[:x] + 50, y: card[:y] + 40, w: card[:w] - 100,
                      items: %w[RESUME QUIT], key: 'pause_menu',
                      row_h: 40, gap: 8
    end

    def leave
      sfx :resume
    end
  end

  class GameOverScene
    def enter
      sfx :gameover
      music :title
    end

    def update
      return unless input.pressed?(:accept)
      goto :title
    end

    def render
      card = Console.ui.card w: 460, h: 260
      Console.draw.text 'GAME OVER',
                        x: card[:x] + (card[:w] / 2.0),
                        y: card[:y] + card[:h] - 80,
                        anchor_x: 0.5, size_px: 36, color: :bad
      final = scene_data(:play)[:score] || 0
      Console.draw.text "final score #{final}",
                        x: card[:x] + (card[:w] / 2.0),
                        y: card[:y] + 90, anchor_x: 0.5, color: :text
      Console.draw.text 'press space to return',
                        x: card[:x] + (card[:w] / 2.0),
                        y: card[:y] + 40, anchor_x: 0.5, color: :muted
    end
  end
end