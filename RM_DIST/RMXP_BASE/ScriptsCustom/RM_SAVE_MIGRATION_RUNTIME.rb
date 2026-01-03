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
    end

    # passivas/skills/quests (placeholders seguros)
    if !instance_variable_defined?(:@rm_passive_equipped_id)
      @rm_passive_equipped_id = nil
    end
    if !instance_variable_defined?(:@rm_skills_equipped)
      @rm_skills_equipped = {}
    end
    if !instance_variable_defined?(:@rm_quests_state)
      @rm_quests_state = {}
    end
  end

  def rm_time_state; @rm_time_state; end
  def rm_passive_equipped_id; @rm_passive_equipped_id; end
  def rm_passive_equipped_id=(v); @rm_passive_equipped_id = v; end
  def rm_skills_equipped; @rm_skills_equipped; end
  def rm_quests_state; @rm_quests_state; end
end
