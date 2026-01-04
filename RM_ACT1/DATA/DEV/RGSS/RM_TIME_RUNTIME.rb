# RM_TIME_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: Clock simples do jogo + fases do dia (Data/RM_CSV/TIME_PHASES_MASTER.csv).
# compatible: RGSS1

module RM_Time
  DEFAULT_PHASES = [
    {:id=>"PH_DAY",        :tone=>[0,0,0,0],   :ticks=>7200},
    {:id=>"PH_AFTERNOON",  :tone=>[10,-10,-10,0], :ticks=>1200},
    {:id=>"PH_NIGHT_START",:tone=>[-40,-40,0,40], :ticks=>1800},
    {:id=>"PH_NIGHT_PEAK", :tone=>[-80,-80,20,80],:ticks=>3600},
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
    fps = Graphics.respond_to?(:frame_rate) ? Graphics.frame_rate : 40
    phases = []
    rows.each do |r|
      pid = r['PhaseID'] || r['TimePhaseID'] || r['ID']
      next if pid.nil? || pid == '' || pid == 'PhaseID'
      order = (r['Ordem'] || r['Order'] || '0').to_i
      dur_sec = (r['DuracaoSeg'] || r['DurationSeconds'] || r['Duration'] || '0').to_i
      ticks = (dur_sec > 0 ? dur_sec * fps : (r['DurationTicks'] || '0').to_i)
      ticks = 3600 if ticks <= 0
      tr = (r['ToneR'] || r['Tone_R'] || '0').to_i
      tg = (r['ToneG'] || r['Tone_G'] || '0').to_i
      tb = (r['ToneB'] || r['Tone_B'] || '0').to_i
      gry = (r['ToneGray'] || r['Tone_Gray'] || '0').to_i
      phases << {:id=>pid, :tone=>[tr,tg,tb,gry], :ticks=>ticks, :order=>order}
    end
    phases.sort! { |a,b| a[:order] <=> b[:order] }
    phases.each { |p| p.delete(:order) }
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
      st[:ticks] = 0
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
