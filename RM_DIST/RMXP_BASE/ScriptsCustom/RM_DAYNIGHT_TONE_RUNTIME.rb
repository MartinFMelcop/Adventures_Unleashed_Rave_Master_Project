# RM_DAYNIGHT_TONE_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: aplica Tone por fase do dia (via RM_Time) em mapas externos.
# compatible: RGSS1

module RM_DayNight
  def self.apply
    return if $game_screen.nil?
    return if RM_WorldContext.is_cave?
    p = RM_Time.current_phase
    t = p[:tone]
    return if t.nil? || t.size < 4
    # tone_change rápido e suave
    $game_screen.start_tone_change(Tone.new(t[0], t[1], t[2], t[3]), 10)
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
