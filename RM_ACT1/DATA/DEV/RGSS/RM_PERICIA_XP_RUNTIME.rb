# RM_PERICIA_XP_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: Skill/Perícia XP runtime + anti-grind + save persistence (RGSS/RMXP)
# audience: ai_only / developer
# notes:
# - Designed for RGSS (Ruby 1.8). Avoid modern Ruby features.
# - Data source in development: CSV files shipped with the game build.
# - Canonical tables live in DATA/CORE (authoring), but the game build should copy them to Data/RM_CSV/.

module RM_PericiaXP
  # ---------
  # File locations in the FINAL GAME BUILD
  # (During authoring, these live under DATA/CORE. The build pipeline should export to Data/RM_CSV/.)
  # ---------
  CSV_DIR = "Data/RM_CSV/"
  CSV_LEVEL_TABLE   = CSV_DIR + "PERICIA_XP_LEVEL_TABLE.csv"
  CSV_XP_SOURCES    = CSV_DIR + "PERICIA_XP_SOURCES.csv"
  CSV_UNLOCKS       = CSV_DIR + "PERICIA_UNLOCKS.csv"

  DEBUG_LOG_PATH = "RM_DEBUG_SKILL_XP.log"

  # Cache tables in memory
  @loaded = false
  @xp_sources_by_action = {}
  @level_table_total_xp = []   # index = level (1..99), value = total xp threshold
  @unlocks_by_pericia   = {}   # pericia_id => [ {level_req, unlock_type, unlock_key, tags} ]

  def self.loaded?
    @loaded == true
  end

  def self.ensure_loaded
    return if loaded?
    load_level_table
    load_xp_sources
    load_unlocks
    @loaded = true
  end

  # Minimal CSV parsing: assumes simple CSV (no commas inside fields).
  def self.read_csv_rows(path)
    rows = []
    return rows if !File.exist?(path)
    f = File.open(path, "rb")
    header = nil
    while !f.eof?
      line = f.gets
      next if line.nil?
      line = line.strip
      next if line.size == 0
      # ignore comments
      next if line[0,1] == "#"
      parts = line.split(",")
      if header.nil?
        header = parts
        next
      end
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

  def self.load_level_table
    rows = read_csv_rows(CSV_LEVEL_TABLE)
    # Expect columns: Level,TotalXP,XPToNext,Curve,Notes
    @level_table_total_xp = []
    rows.each do |r|
      lvl = r["Level"].to_i
      total = r["TotalXP"].to_i
      @level_table_total_xp[lvl] = total
    end
  end

  def self.load_xp_sources
    rows = read_csv_rows(CSV_XP_SOURCES)
    # Expect columns: SourceID,ActionKey,PericiaID,BaseXP,CooldownUnit,CooldownValue,CooldownScope,FirstTimeBonusXP,FirstTimeScope,CapPerDay,Tags,Notes
    @xp_sources_by_action = {}
    rows.each do |r|
      action = r["ActionKey"]
      @xp_sources_by_action[action] = {
        :source_id => r["SourceID"],
        :action_key => action,
        :pericia_id => r["PericiaID"].to_i,
        :base_xp => r["BaseXP"].to_i,
        :cd_unit => r["CooldownUnit"],
        :cd_value => r["CooldownValue"].to_i,
        :cd_scope => r["CooldownScope"],
        :ft_bonus => r["FirstTimeBonusXP"].to_i,
        :ft_scope => r["FirstTimeScope"],
        :tags => r["Tags"],
        :notes => r["Notes"]
      }
    end
  end

  def self.load_unlocks
    rows = read_csv_rows(CSV_UNLOCKS)
    @unlocks_by_pericia = {}
    rows.each do |r|
      pid = r["PericiaID"].to_i
      @unlocks_by_pericia[pid] = [] if @unlocks_by_pericia[pid].nil?
      @unlocks_by_pericia[pid] << {
        :unlock_id => r["UnlockID"],
        :level_req => r["LevelReq"].to_i,
        :unlock_type => r["UnlockType"],
        :unlock_key => r["UnlockKey"],
        :desc => r["DescricaoCurta"],
        :tags => r["Tags"]
      }
    end
  end

  def self.find_source(action_key)
    ensure_loaded
    @xp_sources_by_action[action_key]
  end

  def self.level_for_total_xp(total_xp)
    ensure_loaded
    lvl = 1
    i = 1
    while i <= 99
      threshold = @level_table_total_xp[i]
      if threshold.nil?
        i += 1
        next
      end
      if total_xp >= threshold
        lvl = i
      else
        break
      end
      i += 1
    end
    lvl
  end

  def self.unlocks_for(pericia_id)
    ensure_loaded
    @unlocks_by_pericia[pericia_id] || []
  end

  def self.debug_log(msg)
    begin
      f = File.open(DEBUG_LOG_PATH, "a")
      f.write(msg.to_s + "\n")
      f.close
    rescue
      # ignore logging errors
    end
  end
end

class RM_PericiaXPState
  attr_accessor :xp_by_pericia, :level_by_pericia
  attr_accessor :cooldown_book, :first_time_book
  attr_accessor :day_id, :chapter_id
  attr_accessor :unlocks_book

  def initialize
    @xp_by_pericia = {}
    @level_by_pericia = {}
    @cooldown_book = {}    # key => last_marker (day_id/chapter_id/steps)
    @first_time_book = {}  # key => true
    @unlocks_book = {}     # unlock_key => true
    @day_id = 0
    @chapter_id = 0
  end

  # Set externally by story progression/time system.
  def set_day_id(day_id)
    @day_id = day_id.to_i
  end

  def set_chapter_id(chapter_id)
    @chapter_id = chapter_id.to_i
  end

  def pericia_total_xp(pericia_id)
    @xp_by_pericia[pericia_id] || 0
  end

  def pericia_level(pericia_id)
    lvl = @level_by_pericia[pericia_id]
    return lvl if !lvl.nil?
    lvl = RM_PericiaXP.level_for_total_xp(pericia_total_xp(pericia_id))
    @level_by_pericia[pericia_id] = lvl
    lvl
  end

  def set_pericia_xp(pericia_id, total_xp)
    @xp_by_pericia[pericia_id] = total_xp.to_i
    @level_by_pericia[pericia_id] = RM_PericiaXP.level_for_total_xp(@xp_by_pericia[pericia_id])
  end

  def has_unlock?(unlock_key)
    @unlocks_book[unlock_key] == true
  end

  # Award XP for an action.
  # cooldown_key: stable identifier (node_id, npc_id, recipe_id, waystone_id, etc.).
  # actor: optional; if it responds to rm_pericia_xp_rate(pericia_id), we apply that multiplier.
  def gain_for_action(action_key, cooldown_key, actor)
    src = RM_PericiaXP.find_source(action_key)
    if src.nil?
      RM_PericiaXP.debug_log("[PX] Unknown ActionKey=#{action_key}")
      return 0
    end

    pericia_id = src[:pericia_id]
    award = src[:base_xp]

    # cooldown check
    cd_unit = src[:cd_unit]
    cd_scope = src[:cd_scope]
    cd_val = src[:cd_value]

    scope_key = "G"
    if cd_scope == "PER_KEY"
      scope_key = cooldown_key.to_s
    end

    cd_book_key = "CD|#{src[:source_id]}|#{scope_key}"
    marker = @cooldown_book[cd_book_key]

    blocked = false
    if cd_unit == "DAY"
      if !marker.nil? && marker.to_i >= @day_id
        blocked = true
      end
    elsif cd_unit == "CHAPTER"
      if !marker.nil? && marker.to_i >= @chapter_id
        blocked = true
      end
    elsif cd_unit == "STEPS"
      if defined?($game_party) && !$game_party.nil?
        steps = $game_party.steps
        if !marker.nil? && (steps - marker.to_i) < cd_val
          blocked = true
        end
      end
    else
      # NONE => no cooldown
    end

    if blocked
      RM_PericiaXP.debug_log("[PX] Blocked by cooldown action=#{action_key} key=#{scope_key}")
      return 0
    end

    # first-time bonus
    ft_scope = src[:ft_scope]
    ft_bonus = src[:ft_bonus]
    if ft_bonus > 0 && ft_scope != "NONE"
      ft_scope_key = "G"
      if ft_scope == "PER_KEY"
        ft_scope_key = cooldown_key.to_s
      end
      ft_key = "FT|#{src[:source_id]}|#{ft_scope_key}"
      if @first_time_book[ft_key].nil?
        award += ft_bonus
        @first_time_book[ft_key] = true
      end
    end

    # actor multiplier
    mult = 1.0
    if !actor.nil? && actor.respond_to?(:rm_pericia_xp_rate)
      mult = actor.rm_pericia_xp_rate(pericia_id).to_f
      mult = 1.0 if mult <= 0.0
    end

    award = (award.to_f * mult).to_i
    award = 0 if award < 0

    # commit cooldown marker
    if cd_unit == "DAY"
      @cooldown_book[cd_book_key] = @day_id
    elsif cd_unit == "CHAPTER"
      @cooldown_book[cd_book_key] = @chapter_id
    elsif cd_unit == "STEPS"
      if defined?($game_party) && !$game_party.nil?
        @cooldown_book[cd_book_key] = $game_party.steps
      end
    end

    old_lvl = pericia_level(pericia_id)
    new_total = pericia_total_xp(pericia_id) + award
    set_pericia_xp(pericia_id, new_total)
    new_lvl = pericia_level(pericia_id)

    if new_lvl > old_lvl
      apply_unlocks_for(pericia_id, old_lvl, new_lvl)
      RM_PericiaXP.debug_log("[PX] LevelUp pericia=#{pericia_id} #{old_lvl}→#{new_lvl} total_xp=#{new_total}")
    else
      RM_PericiaXP.debug_log("[PX] XP+ pericia=#{pericia_id} +#{award} total_xp=#{new_total}")
    end

    award
  end

  def apply_unlocks_for(pericia_id, old_lvl, new_lvl)
    unlocks = RM_PericiaXP.unlocks_for(pericia_id)
    unlocks.each do |u|
      req = u[:level_req].to_i
      next if req <= old_lvl
      next if req > new_lvl
      key = u[:unlock_key]
      @unlocks_book[key] = true
      RM_PericiaXP.debug_log("[PX] Unlock pericia=#{pericia_id} lvl=#{req} key=#{key}")
    end
  end
end

# --------------------
# Integration hooks (save persistence)
# --------------------
class Game_System
  attr_accessor :rm_pericia_xp_state
  alias rm_px_initialize initialize
  def initialize
    rm_px_initialize
    @rm_pericia_xp_state = RM_PericiaXPState.new
  end
end

class Game_Actor
  # Optional hook: pericia XP rate multiplier per class.
  # Implement mapping through your class system (DATA/DEV/CLASS_PERICIAS_MASTER.csv).
  def rm_pericia_xp_rate(pericia_id)
    return 1.0
  end
end

# Helper usage from events (Script command):
#   $game_system.rm_pericia_xp_state.set_day_id($game_variables[VAR_DAY_ID])
#   $game_system.rm_pericia_xp_state.gain_for_action("HARVEST_NODE_TIER_1", "NODE_SWAMP_HERB_001", $game_party.actors[0])
#
