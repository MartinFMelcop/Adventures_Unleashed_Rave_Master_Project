# RM_SAVE_MIGRATION_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: Garante que novos campos sejam inicializados em saves antigos.
# compatible: RGSS1

class Game_System
  alias rm__initialize__orig initialize
  def initialize
    rm__initialize__orig
    rm_init_build_fields
  end

  def rm_init_build_fields
    # contexto do mundo (chunk/cave)
    if !instance_variable_defined?(:@rm_world_ctx) || @rm_world_ctx.nil?
      @rm_world_ctx = {:chunk_key=>nil, :is_cave=>false}
    end

    # tempo
    if !instance_variable_defined?(:@rm_time_state) || @rm_time_state.nil?
      @rm_time_state = {:ticks=>0, :phase_id=>nil}
    else
      @rm_time_state[:ticks] ||= 0
      @rm_time_state[:phase_id] = nil if @rm_time_state[:phase_id] == ""
    end

    # passivas/skills/quests (placeholders seguros)
    if !instance_variable_defined?(:@rm_passive_equipped_id)
      @rm_passive_equipped_id = nil
    end
    if !instance_variable_defined?(:@rm_skills_equipped)
      @rm_skills_equipped = {}
    end
    # garante estrutura de 4 slots mesmo em saves antigos
    if @rm_skills_equipped.nil? || !@rm_skills_equipped.is_a?(Hash)
      @rm_skills_equipped = {}
    end
    4.times do |i|
      @rm_skills_equipped[i] = nil unless @rm_skills_equipped.key?(i)
    end
    if !instance_variable_defined?(:@rm_quests_state)
      @rm_quests_state = {}
    end

    if !instance_variable_defined?(:@rm_reputation)
      @rm_reputation = {}
    end

    # flags/eventos (dependência opcional)
    rm_init_flags_events if respond_to?(:rm_init_flags_events)
  end

  def rm_time_state; @rm_time_state; end
  def rm_passive_equipped_id; @rm_passive_equipped_id; end
  def rm_passive_equipped_id=(v); @rm_passive_equipped_id = v; end
  def rm_skills_equipped; @rm_skills_equipped; end
  def rm_quests_state; @rm_quests_state; end

  def rm_after_load!
    rm_init_build_fields
    rm_init_flags_events if respond_to?(:rm_init_flags_events)
    @rm_reputation ||= {}
    @rm_quests_state ||= {}

    # sane defaults para slots/flags críticos
    if @rm_skills_equipped.nil? || !@rm_skills_equipped.is_a?(Hash)
      @rm_skills_equipped = {}
    end
    4.times do |i|
      @rm_skills_equipped[i] = nil unless @rm_skills_equipped.key?(i)
    end
    @rm_passive_equipped_id = nil if @rm_passive_equipped_id == ""
    self
  end
end

class Scene_File
  alias rm__read_save_data read_save_data
  def read_save_data(file)
    rm__read_save_data(file)
    if defined?($game_system) && $game_system && $game_system.respond_to?(:rm_after_load!)
      $game_system.rm_after_load!
    end
  end
end
