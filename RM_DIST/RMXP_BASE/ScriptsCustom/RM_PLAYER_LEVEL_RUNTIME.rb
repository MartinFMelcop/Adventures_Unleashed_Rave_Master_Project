# RM_PLAYER_LEVEL_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: Player Level runtime (Lv1–180) + stat budget application hooks + save persistence (RGSS/RMXP)
# audience: ai_only / developer
# notes:
# - RGSS (Ruby 1.8): avoid modern Ruby features; keep allocations small.
# - Data source in development: CSV files shipped with the game build.
# - Canonical authoring lives in DATA/CORE; build pipeline should export to Data/RM_CSV/.
#
# Data contracts:
# - PLAYER_LEVEL_XP_TABLE.csv columns: Level, TotalXP, XPToNext, Phase, CurveModel
# - PLAYER_LEVEL_STAT_BUDGET.csv columns: Level, Phase, MainStatPoints, HP, SP, BudgetModel, Notes
#
# Save state:
# - $game_system.rm_player_level_state stores total_xp, level, and cumulative budgets.

module RM_PlayerLevel
  CSV_DIR = "Data/RM_CSV/"
  CSV_XP_TABLE    = CSV_DIR + "PLAYER_LEVEL_XP_TABLE.csv"
  CSV_STAT_BUDGET = CSV_DIR + "PLAYER_LEVEL_STAT_BUDGET.csv"

  # Cache
  @@xp_loaded = false
  @@bud_loaded = false
  @@total_xp_by_level = nil
  @@xp_to_next_by_level = nil
  @@main_points_by_level = nil
  @@hp_by_level = nil
  @@sp_by_level = nil
  @@max_level = 180

  def self.read_csv_hashes(path)
    rows = []
    f = File.open(path, "rb")
    header_line = f.gets
    return rows if header_line == nil
    header = header_line.strip.split(",")
    while (line = f.gets)
      line = line.strip
      next if line == ""
      parts = line.split(",")
      row = {}
      i = 0
      while i < header.size
        k = header[i]
        v = (i < parts.size) ? parts[i] : ""
        row[k] = v
        i += 1
      end
      rows << row
    end
    f.close
    rows
  end

  def self.load_xp_table
    return if @@xp_loaded
    rows = read_csv_hashes(CSV_XP_TABLE)
    # 1-index arrays for convenience (index == level)
    @@total_xp_by_level = Array.new(@@max_level + 1, 0)
    @@xp_to_next_by_level = Array.new(@@max_level + 1, 0)
    rows.each do |r|
      lvl = r["Level"].to_i
      next if lvl <= 0 || lvl > @@max_level
      @@total_xp_by_level[lvl] = r["TotalXP"].to_i
      @@xp_to_next_by_level[lvl] = r["XPToNext"].to_i
    end
    @@xp_loaded = true
  end

  def self.load_budget_table
    return if @@bud_loaded
    rows = read_csv_hashes(CSV_STAT_BUDGET)
    @@main_points_by_level = Array.new(@@max_level + 1, 0)
    @@hp_by_level = Array.new(@@max_level + 1, 0)
    @@sp_by_level = Array.new(@@max_level + 1, 0)
    rows.each do |r|
      lvl = r["Level"].to_i
      next if lvl <= 0 || lvl > @@max_level
      @@main_points_by_level[lvl] = r["MainStatPoints"].to_i
      @@hp_by_level[lvl] = r["HP"].to_i
      @@sp_by_level[lvl] = r["SP"].to_i
    end
    @@bud_loaded = true
  end

  def self.max_level
    @@max_level
  end

  def self.total_xp_for_level(level)
    load_xp_table
    l = level.to_i
    l = 1 if l < 1
    l = @@max_level if l > @@max_level
    @@total_xp_by_level[l]
  end

  def self.xp_to_next(level)
    load_xp_table
    l = level.to_i
    l = 1 if l < 1
    l = @@max_level if l > @@max_level
    @@xp_to_next_by_level[l]
  end

  def self.level_for_total_xp(total_xp)
    load_xp_table
    xp = total_xp.to_i
    xp = 0 if xp < 0

    # Binary search on TotalXP thresholds.
    lo = 1
    hi = @@max_level
    while lo < hi
      mid = (lo + hi + 1) / 2
      if @@total_xp_by_level[mid] <= xp
        lo = mid
      else
        hi = mid - 1
      end
    end
    lo
  end

  # Stat budgets (per level gained).
  def self.budget_for_level(level)
    load_budget_table
    l = level.to_i
    l = 1 if l < 1
    l = @@max_level if l > @@max_level
    return @@main_points_by_level[l], @@hp_by_level[l], @@sp_by_level[l]
  end

  # Public API: grant XP to the "player" (usually party leader / actor[0]).
  # Returns number of levels gained.
  #
  # Typical usage from events:
  #   RM_PlayerLevel.grant_xp($game_party.actors[0], 250, "QUEST_COMPLETE")
  #
  def self.grant_xp(actor, amount, source_key)
    state = $game_system.rm_player_level_state
    prev_level = state.level

    add = amount.to_i
    add = 0 if add < 0
    return 0 if add == 0

    # Optional multiplier hook.
    mult = 1.0
    if actor != nil && actor.respond_to?(:rm_player_xp_rate)
      mult = actor.rm_player_xp_rate(source_key)
      mult = 1.0 if mult == nil
    end
    gained = (add * mult).to_i
    gained = 0 if gained < 0

    state.total_xp += gained
    new_level = level_for_total_xp(state.total_xp)
    if new_level > @@max_level
      new_level = @@max_level
    end

    lvups = 0
    if new_level > prev_level
      l = prev_level + 1
      while l <= new_level
        mp, hp, sp = budget_for_level(l)
        state.unspent_main_stat_points += mp
        state.bonus_hp += hp
        state.bonus_sp += sp

        if actor != nil && actor.respond_to?(:rm_apply_level_budget)
          actor.rm_apply_level_budget(l, mp, hp, sp)
        end

        lvups += 1
        l += 1
      end
    end

    state.level = new_level
    lvups
  end
end

# --------------------
# Save persistence
# --------------------
class RM_PlayerLevelState
  attr_accessor :total_xp
  attr_accessor :level
  attr_accessor :unspent_main_stat_points
  attr_accessor :bonus_hp
  attr_accessor :bonus_sp

  attr_accessor :allocated_main_stats
  attr_accessor :respec_count
  def initialize
    @total_xp = 0
    @level = 1
    @unspent_main_stat_points = 0
    @bonus_hp = 0
    @bonus_sp = 0
    @allocated_main_stats = {}
    @respec_count = 0
  end

# --------------------
# Currency adapter (ECON_MOEDAS: B/S/G/P).
# Internal base: Bronze (B).
# Storage: uses $game_party.gold as Bronze total after one-time migration.
# Legacy saves (pre AJ_000239) assumed $game_party.gold stored Silver(S) and are migrated on first access (x100).
# --------------------
module RM_Currency
  BRONZE_PER_SILVER = 100
  SILVER_PER_GOLD   = 100
  GOLD_PER_PLATINUM = 100

  BRONZE_PER_GOLD     = BRONZE_PER_SILVER * SILVER_PER_GOLD
  BRONZE_PER_PLATINUM = BRONZE_PER_GOLD * GOLD_PER_PLATINUM

  def self.ensure_migrated
    return false unless defined?($game_system) && $game_system != nil
    migrated = false
    begin
      migrated = $game_system.instance_variable_get(:@rm_currency_migrated)
    rescue
      migrated = false
    end
    return true if migrated == true

    legacy_s = 0
    begin
      if defined?($game_party) && $game_party != nil && $game_party.respond_to?(:gold)
        legacy_s = $game_party.gold.to_i
      end
    rescue
      legacy_s = 0
    end

    # Legacy interpretation: gold was SILVER; convert to BRONZE base.
    target_b = legacy_s.to_i * BRONZE_PER_SILVER

    begin
      if defined?($game_party) && $game_party != nil && $game_party.respond_to?(:gain_gold) && $game_party.respond_to?(:lose_gold) && $game_party.respond_to?(:gold)
        cur = $game_party.gold.to_i
        delta = target_b - cur
        if delta > 0
          $game_party.gain_gold(delta)
        elsif delta < 0
          $game_party.lose_gold(-delta)
        end
      end
    rescue
      # ignore
    end

    begin
      $game_system.instance_variable_set(:@rm_currency_migrated, true)
    rescue
      # ignore
    end
    true
  end

  def self.bronze_total
    ensure_migrated
    return 0 unless defined?($game_party) && $game_party != nil && $game_party.respond_to?(:gold)
    $game_party.gold.to_i
  end

  def self.total_silver
    (bronze_total / BRONZE_PER_SILVER).to_i
  end

  def self.breakdown_from_bronze(total_b)
    t = total_b.to_i
    p = (t / BRONZE_PER_PLATINUM).to_i
    t = t % BRONZE_PER_PLATINUM
    g = (t / BRONZE_PER_GOLD).to_i
    t = t % BRONZE_PER_GOLD
    s = (t / BRONZE_PER_SILVER).to_i
    b = (t % BRONZE_PER_SILVER).to_i
    return b, s, g, p
  end

  def self.format_wallet
    b, s, g, p = breakdown_from_bronze(bronze_total)
    "P:#{p} G:#{g} S:#{s} B:#{b}"
  end

  def self.format_cost_s(cost_s)
    cs = cost_s.to_i
    b_total = cs * BRONZE_PER_SILVER
    b, s, g, p = breakdown_from_bronze(b_total)
    "Custo #{cs} S (#{p}P #{g}G #{s}S #{b}B)"
  end

  def self.can_afford_s?(cost_s)
    bronze_total >= (cost_s.to_i * BRONZE_PER_SILVER)
  end

  def self.spend_s(cost_s)
    ensure_migrated
    cs = cost_s.to_i
    return true if cs <= 0
    c_b = cs * BRONZE_PER_SILVER
    return false unless defined?($game_party) && $game_party != nil
    return false unless $game_party.respond_to?(:gold) && $game_party.respond_to?(:lose_gold)
    return false if $game_party.gold.to_i < c_b
    $game_party.lose_gold(c_b)
    true
  end
end

end

class Game_System
  attr_accessor :rm_player_level_state
  alias rm_pl_initialize initialize
  def initialize
    rm_pl_initialize
    @rm_player_level_state = RM_PlayerLevelState.new
    @rm_currency_migrated = false
  end
end

class Game_Actor
  # Optional hook: Player XP rate multiplier by source.
  # Return float; default 1.0.
  def rm_player_xp_rate(source_key)
    return 1.0
  end

  # Optional hook: apply budgets on level-up.
  # Default: no-op (budgets accumulated on $game_system.rm_player_level_state).
  def rm_apply_level_budget(level, main_points, hp, sp)
    # Intentionally blank: implement on your stat system layer.
  end
end

