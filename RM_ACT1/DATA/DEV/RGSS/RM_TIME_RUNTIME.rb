# RM_TIME_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: Clock simples do jogo + fases do dia (Data/RM_CSV/TIME_PHASES_MASTER.csv).
# compatible: RGSS1

module RM_Time
  DEFAULT_PHASES = [
    {:id=>"PH_DAY",        :tone=>[0,0,0,0],   :duration_sec=>7200, :switch_dia=>true,  :switch_noite=>false, :luz_casas=>0},
    {:id=>"PH_AFTERNOON",  :tone=>[10,-10,-10,0], :duration_sec=>1200, :switch_dia=>true,  :switch_noite=>false, :luz_casas=>1},
    {:id=>"PH_NIGHT_START",:tone=>[-40,-40,0,40], :duration_sec=>1800, :switch_dia=>false, :switch_noite=>true,  :luz_casas=>2},
    {:id=>"PH_NIGHT_PEAK", :tone=>[-80,-80,20,80],:duration_sec=>3600, :switch_dia=>false, :switch_noite=>true,  :luz_casas=>0},
  ]

  def self._ensure
    return if $game_system.nil?
    if !$game_system.instance_variable_defined?(:@rm_time_state) || $game_system.instance_variable_get(:@rm_time_state).nil?
      st = {
        :ticks=>0,
        :phase_id=>nil,
        :last_frame=>Graphics.respond_to?(:frame_count) ? Graphics.frame_count : 0
      }
      $game_system.instance_variable_set(:@rm_time_state, st)
    end
  end

  def self._load_flags
    @var_flags = { :phase=>nil, :in_phase=>nil, :last_frame=>nil, :dia_counter=>nil, :luz_casas=>nil }
    @switch_flags = { :dia=>nil, :noite=>nil }
    rows = RM_Data.csv_rows('Data/RM_CSV/TIME_FLAGS.csv')
    rows.each do |r|
      name = r['Nome']
      next if name.nil? || name.strip == ''
      case r['Tipo']
      when 'VAR'
        case name
        when 'V_TIME_PHASE' then @var_flags[:phase] = _resolve_variable_id(name)
        when 'V_TIME_IN_PHASE' then @var_flags[:in_phase] = _resolve_variable_id(name)
        when 'V_TIME_LAST_FRAME' then @var_flags[:last_frame] = _resolve_variable_id(name)
        when 'V_DIA' then @var_flags[:dia_counter] = _resolve_variable_id(name)
        when 'V_LUZ_CASAS' then @var_flags[:luz_casas] = _resolve_variable_id(name)
        end
      when 'SWITCH'
        case name
        when 'S_DIA' then @switch_flags[:dia] = _resolve_switch_id(name)
        when 'S_NOITE' then @switch_flags[:noite] = _resolve_switch_id(name)
        end
      end
    end
  rescue
    @var_flags ||= {}
    @switch_flags ||= {}
  end

  def self._resolve_variable_id(name)
    return nil if $data_system.nil? || $data_system.variables.nil?
    $data_system.variables.index(name)
  end

  def self._resolve_switch_id(name)
    return nil if $data_system.nil? || $data_system.switches.nil?
    $data_system.switches.index(name)
  end

  def self._load_phases
    rows = RM_Data.csv_rows('Data/RM_CSV/TIME_PHASES_MASTER.csv')
    return DEFAULT_PHASES if rows.nil? || rows.empty?
    phases = []
    rows.each do |r|
      pid = r['PhaseID'] || r['TimePhaseID'] || r['ID']
      next if pid.nil? || pid == '' || pid == 'PhaseID'
      order = (r['Ordem'] || r['Order'] || '0').to_i
      dur_sec = (r['DuracaoSeg'] || r['DurationSeconds'] || r['Duration'] || '0').to_i
      dur_sec = 3600 if dur_sec <= 0
      tr = (r['ToneR'] || r['Tone_R'] || '0').to_i
      tg = (r['ToneG'] || r['Tone_G'] || '0').to_i
      tb = (r['ToneB'] || r['Tone_B'] || '0').to_i
      gry = (r['ToneGray'] || r['Tone_Gray'] || '0').to_i
      phases << {
        :id=>pid,
        :tone=>[tr,tg,tb,gry],
        :duration_sec=>dur_sec,
        :switch_dia=>(r['SwitchDia'] || r['Switch_Dia'] || '').to_s.downcase == 'true',
        :switch_noite=>(r['SwitchNoite'] || r['Switch_Noite'] || '').to_s.downcase == 'true',
        :luz_casas=>(r['LuzCasasEstado'] || '0').to_i,
        :order=>order
      }
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

  def self.flags
    _load_flags if @var_flags.nil? || @switch_flags.nil?
    { :vars=>@var_flags, :switches=>@switch_flags }
  end

  def self.current_phase
    _ensure
    st = $game_system.instance_variable_get(:@rm_time_state)
    pid = st[:phase_id]
    if pid.nil?
      st[:phase_id] = phases[0][:id]
      st[:ticks] = 0
      st[:last_frame] = Graphics.respond_to?(:frame_count) ? Graphics.frame_count : 0
      _apply_flags(st, phases[0], 0)
      return phases[0]
    end
    phases.each { |p| return p if p[:id] == pid }
    phases[0]
  end

  def self._apply_flags(state, phase, time_in_phase)
    f = flags
    if f[:vars][:phase]
      $game_variables[f[:vars][:phase]] = phases.index(phase) || 0
    end
    if f[:vars][:in_phase]
      $game_variables[f[:vars][:in_phase]] = time_in_phase.to_i
    end
    if f[:vars][:last_frame]
      $game_variables[f[:vars][:last_frame]] = state[:last_frame]
    end
    if f[:vars][:luz_casas]
      $game_variables[f[:vars][:luz_casas]] = phase[:luz_casas] || 0
    end
    if f[:switches][:dia]
      $game_switches[f[:switches][:dia]] = (phase[:switch_dia] == true)
    end
    if f[:switches][:noite]
      $game_switches[f[:switches][:noite]] = (phase[:switch_noite] == true)
    end
  rescue
  end

  def self.advance_tick
    _ensure
    st = $game_system.instance_variable_get(:@rm_time_state)
    cur = current_phase
    fps = Graphics.respond_to?(:frame_rate) ? Graphics.frame_rate : 40
    frame_now = Graphics.respond_to?(:frame_count) ? Graphics.frame_count : (st[:last_frame] || 0)
    last = st[:last_frame] || frame_now
    delta_frames = frame_now - last
    delta_frames = 1 if delta_frames <= 0
    delta_sec = delta_frames.to_f / fps
    st[:last_frame] = frame_now
    st[:ticks] = (st[:ticks] || 0) + delta_sec

    wrapped = false
    if st[:ticks] >= cur[:duration_sec]
      st[:ticks] = st[:ticks] % cur[:duration_sec]
      idx = phases.index(cur) || 0
      nxt = phases[(idx + 1) % phases.size]
      st[:phase_id] = nxt[:id]
      cur = nxt
      wrapped = (idx + 1) % phases.size == 0
      if wrapped && flags[:vars][:dia_counter]
        $game_variables[flags[:vars][:dia_counter]] = ($game_variables[flags[:vars][:dia_counter]] || 0) + 1
      end
    end
    _apply_flags(st, cur, st[:ticks])
    cur
  rescue
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
