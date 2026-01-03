# RM_MOVEMENT_RUN_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: Walk/Run support on map (speed + optional sprite swap + optional footstep SE).
# audience: AI-only (technical)
# ruby: RGSS / RPG Maker XP (Ruby 1.8)
#
# Behavior (default):
# - Hold SHIFT to run (fallback key: Input::A).
# - Run speed = walk speed + RUN_SPEED_DELTA.
# - If a run sprite exists (base + RUN_SPRITE_SUFFIX), swap while running; else fallback.
#
# Sprite naming convention (optional):
# - If actor's character_name is "Hero", run sprite should be "Hero_run" (suffix configurable).
# - Stored in Graphics/Characters/.
#
# Audio naming convention (optional):
# - If enabled, will try to play Audio/SE/<SE_WALK> and Audio/SE/<SE_RUN> (wav/ogg/mp3/wma).
#
# Notes:
# - Insert this script BEFORE "Main" in Scripts.rxdata.
# - Safe by default: if assets are missing, silently falls back.

module RM_RunMovement
  # --- config ---
  HOLD_TO_RUN = true        # true: hold key; false: toggle
  TOGGLE_RUN  = false       # if true, Shift toggles run state
  RUN_SPEED_DELTA = 1       # +1 over walk speed (default walk speed is usually 4)
  RUN_SPRITE_SUFFIX = "_run"
  USE_RUN_SPRITES_IF_AVAILABLE = true

  PLAY_FOOTSTEPS = false
  SE_WALK = "step_walk"
  SE_RUN  = "step_run"
  SE_VOL  = 80
  SE_PITCH_WALK = 100
  SE_PITCH_RUN  = 115

  def self.key_const
    if defined?(Input::SHIFT)
      return Input::SHIFT
    end
    # RPG Maker XP commonly maps Shift to Input::A
    return Input::A
  end

  def self.run_pressed?
    return Input.press?(key_const)
  end

  def self.run_trigger?
    return Input.trigger?(key_const)
  end

  def self.audio_file_exists?(base_path)
    begin
      return true if FileTest.exist?(base_path)
      return true if FileTest.exist?(base_path + ".wav")
      return true if FileTest.exist?(base_path + ".ogg")
      return true if FileTest.exist?(base_path + ".mp3")
      return true if FileTest.exist?(base_path + ".wma")
    rescue
    end
    return false
  end
end

class Game_Player < Game_Character
  attr_reader :rm_run_active

  alias rm_runmovement__orig_refresh refresh
  def refresh
    rm_runmovement__orig_refresh
    begin
      # capture base sprite name after refresh
      @rm_run_base_character_name = @character_name
    rescue
    end
  end

  alias rm_runmovement__orig_update update
  def update
    rm_runmovement_update_state
    rm_runmovement__orig_update
  end

  alias rm_runmovement__orig_increase_steps increase_steps
  def increase_steps
    rm_runmovement__orig_increase_steps
    rm_runmovement_play_footstep
  end

  # ------------------------------------------------------------------------
  # * Run state update (called every frame)
  # ------------------------------------------------------------------------
  def rm_runmovement_update_state
    # Do not interfere with forced movement.
    return if @move_route_forcing

    # Disable on vehicle (boat/ship/airship) if present in this project.
    begin
      if @vehicle_type != nil and @vehicle_type != -1
        rm_runmovement_set_active(false)
        return
      end
    rescue
    end

    # Establish walk speed baseline once (or if corrupted).
    @rm_walk_speed = @move_speed if @rm_walk_speed == nil || @rm_walk_speed <= 0

    active = false
    if RM_RunMovement::TOGGLE_RUN
      @rm_run_toggled = false if @rm_run_toggled == nil
      if RM_RunMovement.run_trigger?
        @rm_run_toggled = !@rm_run_toggled
      end
      active = @rm_run_toggled
    else
      active = RM_RunMovement.run_pressed?
    end

    rm_runmovement_set_active(active)
  end

  # ------------------------------------------------------------------------
  # * Apply run speed + sprite (safe fallback)
  # ------------------------------------------------------------------------
  def rm_runmovement_set_active(active)
    @rm_run_active = active

    if active
      @move_speed = @rm_walk_speed + RM_RunMovement::RUN_SPEED_DELTA
    else
      @move_speed = @rm_walk_speed
    end

    rm_runmovement_apply_sprite
  end

  def rm_runmovement_apply_sprite
    return unless RM_RunMovement::USE_RUN_SPRITES_IF_AVAILABLE

    # Resolve base sprite name (prefer lead actor).
    base = nil
    begin
      if $game_party != nil && $game_party.actors != nil && $game_party.actors.size > 0
        base = $game_party.actors[0].character_name
      end
    rescue
    end

    base = @rm_run_base_character_name if (base == nil || base == "")
    base = @character_name if (base == nil || base == "")

    @rm_run_base_character_name = base if (@rm_run_base_character_name == nil || @rm_run_base_character_name == "")

    if @rm_run_active
      run_name = base + RM_RunMovement::RUN_SPRITE_SUFFIX
      return if @character_name == run_name
      begin
        RPG::Cache.character(run_name, 0)
        @character_name = run_name
      rescue
        @character_name = base
      end
    else
      @character_name = base
    end
  end

  def rm_runmovement_play_footstep
    return unless RM_RunMovement::PLAY_FOOTSTEPS
    se = @rm_run_active ? RM_RunMovement::SE_RUN : RM_RunMovement::SE_WALK
    base_path = "Audio/SE/" + se.to_s
    return unless RM_RunMovement.audio_file_exists?(base_path)

    begin
      pitch = @rm_run_active ? RM_RunMovement::SE_PITCH_RUN : RM_RunMovement::SE_PITCH_WALK
      Audio.se_play(base_path, RM_RunMovement::SE_VOL, pitch)
    rescue
    end
  end
end
