# RM_QA_SAVE_VALIDATION.rb
# rm_rgss_spec: 1
# purpose: Helper para QA automatizado de save/load (flags, eventos e quests).
# audience: AI-only (technical)
# ruby: RGSS / RPG Maker XP (Ruby 1.8)
#
# Uso previsto (QA manual ou pré-pack):
#   snapshot = RM_QA_SaveValidation.snapshot_state($game_system)
#   # executar save + load
#   diff = RM_QA_SaveValidation.diff_state(snapshot, $game_system)
#   raise("Save regression: #{diff}") if diff.size > 0
#
# Cobertura:
# - Flags persistidas via RM_FlagStore (rm_flag_store)
# - Eventos recentes persistidos via rm_event_store
# - Estado básico de quests (RM_QuestState)

module RM_QA_SaveValidation
  module_function

  def snapshot_state(game_system)
    {
      :flags => snapshot_flags(game_system),
      :events => snapshot_events(game_system),
      :quests => snapshot_quests
    }
  end

  def snapshot_flags(game_system)
    store = game_system.respond_to?(:rm_flag_store) ? game_system.rm_flag_store : nil
    return {} if store == nil
    {
      :turn => store.turn,
      :global => deep_copy(store.instance_variable_get(:@global)),
      :npc => deep_copy(store.instance_variable_get(:@npc)),
      :rel => deep_copy(store.instance_variable_get(:@rel))
    }
  end

  def snapshot_events(game_system)
    store = game_system.respond_to?(:rm_event_store) ? game_system.rm_event_store : nil
    return {} if store == nil
    deep_copy(store.instance_variable_get(:@events))
  end

  def snapshot_quests
    return {} unless defined?(RM_QuestState)
    data = {}
    RM_QuestState.instance_variables.each do |ivar|
      data[ivar] = deep_copy(RM_QuestState.instance_variable_get(ivar))
    end
    data
  end

  def diff_state(before, after_system)
    after = snapshot_state(after_system)
    diffs = {}
    [:flags, :events, :quests].each do |k|
      b = before[k]
      a = after[k]
      next if b == a
      diffs[k] = { :before => b, :after => a }
    end
    diffs
  end

  def deep_copy(obj)
    Marshal.load(Marshal.dump(obj))
  rescue
    obj
  end
end
