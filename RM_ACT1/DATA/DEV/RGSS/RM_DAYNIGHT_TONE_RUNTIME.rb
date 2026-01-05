# RM_DAYNIGHT_TONE_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: aplica Tone por fase do dia (via RM_Time) em mapas externos.
# compatible: RGSS1

module RM_DayNight
  @last_phase_id = nil
  @last_map_id = nil

  def self.reset!(reason=nil)
    @last_phase_id = nil
    @last_map_id = nil
  end

  def self.apply(force=false)
    return if $game_screen.nil?
    return if RM_WorldContext.is_cave?
    p = RM_Time.current_phase
    t = p[:tone]
    return if t.nil? || t.size < 4
    map_id = $game_map ? $game_map.map_id : nil
    return if !force && @last_phase_id == p[:id] && @last_map_id == map_id
    # tone_change rápido e suave
    $game_screen.start_tone_change(Tone.new(t[0], t[1], t[2], t[3]), 10)
    @last_phase_id = p[:id]
    @last_map_id = map_id
  rescue
  end
end

if defined?(Scene_Map)
  class Scene_Map
    alias rm__update__tone_orig update
    def update
      rm__update__tone_orig
      RM_DayNight.apply
    rescue
    end
  end
end

if defined?(Game_Map)
  class Game_Map
    alias rm__setup__tone_orig setup
    def setup(map_id)
      RM_DayNight.reset!(:map_change)
      rm__setup__tone_orig(map_id)
      RM_DayNight.apply(true)
    rescue
    end
  end
end
