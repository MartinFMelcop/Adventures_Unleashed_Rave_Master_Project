# RM_TIME_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: Clock simples do jogo + fases do dia (Data/RM_CSV/TIME_PHASES_MASTER.csv).
# compatible: RGSS1

module RM_Time
  DEFAULT_PHASES = [
    {:id=>"DAWN", :tone=>[0,0,0,0], :ticks=>3600},
    {:id=>"DAY",  :tone=>[0,0,0,0], :ticks=>7200},
    {:id=>"DUSK", :tone=>[-20,-20,0,30], :ticks=>3600},
    {:id=>"NIGHT",:tone=>[-68,-68,0,120], :ticks=>7200},
  ]

  def self._ensure
    return if $game_system.nil?
    if !$game_system.instance_variable_defined?(:@rm_time_state) || $game_system.instance_variable_get(:@rm_time_state).nil?
      $game_system.instance_variable_set(:@rm_time_state, {:ticks=>0, :phase_id=>nil})
    end
  end

  def self._load_phases
    rows = RM_Data.csv_rows('Data/RM_CSV/TIME_PHASES_MASTER.csv')
    return DEFAULT_PHASES if rows.nil? || rows.empty?
    phases = []
    rows.each do |r|
      pid = r['TimePhaseID'] || r['PhaseID'] || r['ID']
      next if pid.nil? || pid == '' || pid == 'TimePhaseID'
      dur = (r['DurationTicks'] || r['Duration'] || '3600').to_i
      tr = (r['Tone_R'] || r['ToneR'] || '0').to_i
      tg = (r['Tone_G'] || r['ToneG'] || '0').to_i
      tb = (r['Tone_B'] || r['ToneB'] || '0').to_i
      gry = (r['Tone_Gray'] || r['ToneGray'] || '0').to_i
      phases << {:id=>pid, :tone=>[tr,tg,tb,gry], :ticks=>dur}
    end
    phases = DEFAULT_PHASES if phases.empty?
    phases
  rescue
    DEFAULT_PHASES
  end

  def self.phases
    @phases ||= _load_phases
  end

  def self.current_phase
    _ensure
    st = $game_system.instance_variable_get(:@rm_time_state)
    pid = st[:phase_id]
    if pid.nil?
      st[:phase_id] = phases[0][:id]
      return phases[0]
    end
    phases.each { |p| return p if p[:id] == pid }
    phases[0]
  end

  def self.advance_tick
    _ensure
    st = $game_system.instance_variable_get(:@rm_time_state)
    st[:ticks] = (st[:ticks] || 0) + 1
    # rotate phases
    cur = current_phase
    if st[:ticks] >= cur[:ticks]
      st[:ticks] = 0
      idx = phases.index(cur) || 0
      nxt = phases[(idx + 1) % phases.size]
      st[:phase_id] = nxt[:id]
    end
  end
end

# hook leve: avançar tempo no mapa (não avança em menus)
if defined?(Scene_Map)
  class Scene_Map
    alias rm__update__time_orig update
    def update
      rm__update__time_orig
      RM_Time.advance_tick
    rescue
      # nunca derrubar o jogo por clock
    end
  end
end
