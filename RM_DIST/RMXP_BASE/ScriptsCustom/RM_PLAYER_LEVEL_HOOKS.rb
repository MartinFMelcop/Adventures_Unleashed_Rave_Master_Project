# RM_PLAYER_LEVEL_HOOKS.rb
# rm_rgss_spec: 1
# purpose: Integrate player XP sources + anti-grind + debug overlay + minimal stat allocation UI (stub).
#
# Authoring note:
# - Canonical data lives in DATA/CORE (this repo snapshot).
# - Game build should export needed CSVs into Data/RM_CSV/.
#
# Dependencies:
# - Requires RM_PLAYER_LEVEL_RUNTIME.rb loaded before this file.

module RM_WorldTime
  # Simple counters that events can set.
  # Used for cooldowns and caps (DAY/CHAPTER).
  def self.day
    $game_system.rm_world_time_state.day
  end

  def self.chapter
    $game_system.rm_world_time_state.chapter
  end

  def self.set_day(v)
    $game_system.rm_world_time_state.day = v.to_i
  end

  def self.set_chapter(v)
    $game_system.rm_world_time_state.chapter = v.to_i
  end
end

class RM_WorldTimeState
  attr_accessor :day
  attr_accessor :chapter
  def initialize
    @day = 0
    @chapter = 0
  end
end

class Game_System
  def rm_world_time_state
    @rm_world_time_state = RM_WorldTimeState.new if @rm_world_time_state == nil
    @rm_world_time_state
  end

  def rm_player_xp_state
    @rm_player_xp_state = RM_PlayerXPState.new if @rm_player_xp_state == nil
    @rm_player_xp_state
  end
end

class RM_PlayerXPState
  # cooldowns: key => expire_value (integer), unit decides meaning
  attr_accessor :cooldowns_day
  attr_accessor :cooldowns_chapter
  # daily caps: key_day => count
  attr_accessor :daily_counts
  # first-time tracking: key => true
  attr_accessor :first_time_done

  def initialize
    @cooldowns_day = {}
    @cooldowns_chapter = {}
    @daily_counts = {}
    @first_time_done = {}
  end
end

module RM_PlayerXP
  CSV_DIR = "Data/RM_CSV/"
  CSV_PLAYER_XP_SOURCES = CSV_DIR + "PLAYER_XP_SOURCES.csv"

  @@loaded = false
  @@sources_by_key = {}

  ALLOWED_COOLDOWN_UNIT = ["NONE","DAY","CHAPTER"]
  ALLOWED_SCOPE = ["NONE","GLOBAL","PER_KEY"]
  # FirstTimeScope uses same values as CooldownScope for now.

  # Minimal CSV parsing: assumes simple CSV (no commas inside fields).
  def self.read_csv_rows(path)
    rows = []
    return rows if !File.exist?(path)
    f = File.open(path, "rb")
    header = nil
    while !f.eof?
      line = f.gets
      next if line == nil
      line = line.strip
      next if line.size == 0
      next if line[0,1] == "#"
      parts = line.split(",")
      if header == nil
        header = parts
        next
      end
      row = {}
      i = 0
      while i < header.size && i < parts.size
        row[header[i]] = parts[i]
        i += 1
      end
      rows << row
    end
    f.close
    rows
  end

  def self.load_sources
    return if @@loaded
    @@sources_by_key = {}
    rows = read_csv_rows(CSV_PLAYER_XP_SOURCES)
    rows.each do |r|
      k = r["SourceKey"]
      next if k == nil || k.size == 0
      @@sources_by_key[k] = r
    end
    @@loaded = true
  end

  def self.source(source_key)
    load_sources
    @@sources_by_key[source_key]
  end

  # Grants XP using a SourceKey. context_key is used for PER_KEY scopes.
  #
  # Examples (Event Script Call):
  #   RM_PlayerXP.grant("QUEST_SIDE_COMPLETE", "QST-ROSE-01")
  #   RM_PlayerXP.grant("COMBAT_BOSS_CALAMITY", "CAL-0003")
  #   RM_PlayerXP.grant("BOOK_PAGE_FOUND", "PAGE-0007")
  #
  # Returns levels gained.
  def self.grant(source_key, context_key=nil, actor=nil, override_amount=nil)
    actor = $game_party.actors[0] if actor == nil
    r = source(source_key)
    base = override_amount != nil ? override_amount.to_i : (r != nil ? r["BaseXP"].to_i : 0)
    return 0 if base <= 0

    state = $game_system.rm_player_xp_state

    # Determine effective keys
    scope = (r != nil ? r["CooldownScope"] : "NONE")
    unit  = (r != nil ? r["CooldownUnit"]  : "NONE")
    cval  = (r != nil ? r["CooldownValue"].to_i : 0)
    cap_per_day = (r != nil && r["CapPerDay"] != nil && r["CapPerDay"].size > 0) ? r["CapPerDay"].to_i : 0

    cd_key = source_key
    if scope == "PER_KEY"
      ck = (context_key != nil ? context_key.to_s : "nil")
      cd_key = source_key + ":" + ck
    end

    # Cooldown check
    if unit == "DAY" && cval > 0
      exp = state.cooldowns_day[cd_key]
      if exp != nil && RM_WorldTime.day < exp
        return 0
      end
      state.cooldowns_day[cd_key] = RM_WorldTime.day + cval
    elsif unit == "CHAPTER" && cval > 0
      exp = state.cooldowns_chapter[cd_key]
      if exp != nil && RM_WorldTime.chapter < exp
        return 0
      end
      state.cooldowns_chapter[cd_key] = RM_WorldTime.chapter + cval
    end

    # Daily cap check (counts per day per source_key)
    if cap_per_day > 0
      day_key = RM_WorldTime.day.to_s + ":" + source_key
      cur = state.daily_counts[day_key]
      cur = 0 if cur == nil
      return 0 if cur >= cap_per_day
      state.daily_counts[day_key] = cur + 1
    end

    # First time bonus (per-key)
    ft_bonus = (r != nil ? r["FirstTimeBonusXP"].to_i : 0)
    ft_scope = (r != nil ? r["FirstTimeScope"] : "NONE")
    ft_key = source_key
    if ft_scope == "PER_KEY"
      ck = (context_key != nil ? context_key.to_s : "nil")
      ft_key = source_key + ":" + ck
    end
    if ft_bonus > 0
      if state.first_time_done[ft_key] == nil
        base += ft_bonus
        state.first_time_done[ft_key] = true
      end
    end

    RM_PlayerLevel.grant_xp(actor, base, source_key)
  end
end

# --------------------
# Minimal stat allocation (stub)
# --------------------
class RM_PlayerLevelState
  attr_accessor :allocated_main_stats
  attr_accessor :respec_count
end

module RM_StatAlloc
  STAT_KEYS = ["STR","INT","AGI","DEX","VIT","WIS"]


  # Respec economy model (see DATA/GOV/RMXP_PLAYER_LEVEL_RUNTIME_BINDINGS.md)
  RESPEC_BASE_S = 5
  RESPEC_LEVEL_DIV = 5
  RESPEC_MULT = 1.25

  def self.ensure_respec_count(state)
    return 0 if state == nil
    # state may be older saves without this field
    if !state.respond_to?(:respec_count) || state.respec_count == nil
      begin
        state.respec_count = 0
      rescue
        # ignore
      end
    end
    state.respec_count.to_i
  end

  def self.respec_cost_s(level, respec_count)
    lvl = level.to_i
    lvl = 1 if lvl < 1
    rc = respec_count.to_i
    per = (lvl + (RESPEC_LEVEL_DIV - 1)) / RESPEC_LEVEL_DIV
    ((RESPEC_BASE_S + per) * (RESPEC_MULT ** rc)).ceil
  end

  # Currency adapter (default: treat $game_party.gold as Silver(S) units).
  def self.currency_s
    return (RM_Currency.total_silver rescue 0)
  end

  def self.spend_s(amount)
    return (RM_Currency.spend_s(amount) rescue false)
  end


  def self.ensure_alloc_hash(state)
    state.allocated_main_stats = {} if state.allocated_main_stats == nil
  end

  # Stores allocation in save state (does not mutate core RMXP params yet).
  def self.allocate(stat_key, amount, actor=nil)
    actor = $game_party.actors[0] if actor == nil
    st = $game_system.rm_player_level_state
    ensure_alloc_hash(st)
    amt = amount.to_i
    return false if amt <= 0
    return false if st.unspent_main_stat_points < amt
    k = stat_key.to_s.upcase
    st.allocated_main_stats[k] = 0 if st.allocated_main_stats[k] == nil
    st.allocated_main_stats[k] += amt
    st.unspent_main_stat_points -= amt

    # Apply allocation to actor params (idempotent).
    if actor != nil && actor.respond_to?(:rm_sync_player_level_state)
      actor.rm_sync_player_level_state
    end

    true
  end


  # Respec: returns allocated points to the unspent pool and resets allocations.
  # Event-friendly: call RM_StatAlloc.respec_all or RM_StatAlloc.respec_stat("STR", 5)
  def self.respec_all(actor=nil)
    actor = $game_party.actors[0] if actor == nil
    st = $game_system.rm_player_level_state
    ensure_alloc_hash(st)

    # Sum allocations
    alloc = st.allocated_main_stats
    alloc = {} if alloc == nil
    sum = 0
    STAT_KEYS.each do |k|
      v = alloc[k]
      v = alloc[k.to_s] if v == nil
      sum += v.to_i if v != nil
    end

    st.unspent_main_stat_points = 0 if st.unspent_main_stat_points == nil
    st.unspent_main_stat_points += sum

    # Reset allocations
    st.allocated_main_stats = {}

    if actor != nil && actor.respond_to?(:rm_sync_player_level_state)
      actor.rm_sync_player_level_state
    end
    true
  end

  # Convenience alias
  def self.respec(actor=nil)
    respec_all(actor)
  end

  # Respec a single stat (full reset by default; optional partial amount).
  def self.respec_stat(stat_key, amount=nil, actor=nil)
    actor = $game_party.actors[0] if actor == nil
    st = $game_system.rm_player_level_state
    ensure_alloc_hash(st)

    k = stat_key.to_s.upcase
    cur = st.allocated_main_stats[k]
    cur = 0 if cur == nil

    amt = cur
    if amount != nil
      a = amount.to_i
      a = 0 if a < 0
      amt = (a <= cur ? a : cur)
    end

    return false if amt <= 0

    st.allocated_main_stats[k] = cur - amt
    st.unspent_main_stat_points = 0 if st.unspent_main_stat_points == nil
    st.unspent_main_stat_points += amt

    # Cleanup key if zero
    st.allocated_main_stats.delete(k) if st.allocated_main_stats[k].to_i <= 0

    if actor != nil && actor.respond_to?(:rm_sync_player_level_state)
      actor.rm_sync_player_level_state
    end
    true
  end

  # Event-friendly scene hook.
  def self.open_scene(actor=nil)
    actor = $game_party.actors[0] if actor == nil
    $scene = Scene_RM_StatAllocation.new(actor)
  end
end

class Window_RM_StatAlloc < Window_Command
  def initialize(actor)
    @actor = actor
    commands = RM_StatAlloc::STAT_KEYS + ["Respec"]
    super(200, commands)
    self.x = 0
    self.y = 0
    refresh
  end

  def rm_command_name(index=nil)
    index = self.index if index == nil
    @commands[index]
  end

  def refresh
    super
  end
end

# --------------------
# Apply player level state (budgets + allocations) to RMXP parameters
# --------------------
module RM_PlayerLevelParamSync
  # Map from main stat key to RMXP plus ivar.
  MAIN_PLUS_IVAR = {
    "STR" => "@str_plus",
    "DEX" => "@dex_plus",
    "AGI" => "@agi_plus",
    "INT" => "@int_plus"
  }

  HP_PLUS_IVAR = "@maxhp_plus"
  SP_PLUS_IVAR = "@maxsp_plus"

  # Optional: if your project uses VIT/WIS as primary stats, set these ratios.
  # (Default 0 keeps behavior stable until balance rules are defined.)
  VIT_TO_HP = 4
  WIS_TO_SP = 2

  def self.int(v)
    return 0 if v == nil
    v.to_i
  end

  def self.desired_plus_hash(state)
    alloc = state.allocated_main_stats
    alloc = {} if alloc == nil

    d = {}
    MAIN_PLUS_IVAR.keys.each do |k|
      d[k] = int(alloc[k])
    end

    d["_HP"] = int(state.bonus_hp) + int(alloc["VIT"]) * VIT_TO_HP
    d["_SP"] = int(state.bonus_sp) + int(alloc["WIS"]) * WIS_TO_SP
    d
  end

  def self.apply(actor, state)
    desired = desired_plus_hash(state)
    actor.rm_apply_rm_level_state_plus(desired)
  end
end

class Game_Actor
  def rm_level_state_applied_plus
    @rm_level_state_applied_plus = {} if @rm_level_state_applied_plus == nil
    @rm_level_state_applied_plus
  end

  # Idempotent: applies only deltas against the last applied snapshot.
  def rm_apply_rm_level_state_plus(desired)
    applied = rm_level_state_applied_plus

    # Main stats
    RM_PlayerLevelParamSync::MAIN_PLUS_IVAR.each do |k, iv|
      target = desired[k] || 0
      cur = applied[k] || 0
      delta = target - cur
      if delta != 0
        base = instance_variable_get(iv)
        base = 0 if base == nil
        instance_variable_set(iv, base + delta)
        applied[k] = target
      end
    end

    # HP / SP bonuses
    {"_HP" => RM_PlayerLevelParamSync::HP_PLUS_IVAR, "_SP" => RM_PlayerLevelParamSync::SP_PLUS_IVAR}.each do |k, iv|
      target = desired[k] || 0
      cur = applied[k] || 0
      delta = target - cur
      if delta != 0
        base = instance_variable_get(iv)
        base = 0 if base == nil
        instance_variable_set(iv, base + delta)
        applied[k] = target
      end
    end

    # Clamp current HP/SP after max changes.
    begin
      @hp = [@hp, maxhp].min if @hp != nil
      @sp = [@sp, maxsp].min if @sp != nil
    rescue
    end
  end

  def rm_sync_player_level_state
    st = $game_system.rm_player_level_state
    RM_PlayerLevelParamSync.apply(self, st) if st != nil
  end

  # Hook called by RM_PLAYER_LEVEL_RUNTIME on each level-up budget step.
  def rm_apply_level_budget(level, main_points, hp, sp)
    rm_sync_player_level_state
  end

  alias rm_plps_setup setup
  def setup(actor_id)
    rm_plps_setup(actor_id)
    rm_sync_player_level_state
  end
end
class Window_RM_StatAllocInfo < Window_Base
  def initialize(actor)
    super(200, 0, 440, 200)
    @actor = actor
    @notice = ""
    refresh
  end

  def set_notice(text)
    @notice = text.to_s
    refresh
  end

  def refresh
    self.contents.clear
    st = $game_system.rm_player_level_state

    pts = st.unspent_main_stat_points rescue 0
    tot = st.total_xp rescue 0
    lvl = st.level rescue 1

    rc = 0
    begin
      rc = st.respec_count.to_i if st != nil && st.respond_to?(:respec_count) && st.respec_count != nil
    rescue
      rc = 0
    end

    money_s = 0
    begin
      money_s = RM_StatAlloc.currency_s
    rescue
      money_s = 0
    end

    alloc = {}
    begin
      alloc = st.allocated_main_stats
      alloc = {} if alloc == nil
    rescue
      alloc = {}
    end

    self.contents.draw_text(0, 0, 420, 24, "Level: #{lvl}   TotalXP: #{tot}")
    self.contents.draw_text(0, 24, 420, 24, "Unspent: #{pts}   Respec#: #{rc}   Wallet: #{(RM_Currency.format_wallet rescue money_s)}")

    a1 = "Alloc: STR+#{alloc['STR'].to_i} INT+#{alloc['INT'].to_i} AGI+#{alloc['AGI'].to_i} DEX+#{alloc['DEX'].to_i}"
    a2 = "      VIT+#{alloc['VIT'].to_i} WIS+#{alloc['WIS'].to_i}"
    self.contents.draw_text(0, 48, 420, 24, a1)
    self.contents.draw_text(0, 72, 420, 24, a2)

    self.contents.draw_text(0, 120, 420, 24, @notice.to_s)
    self.contents.draw_text(0, 144, 420, 24, "Enter: +1 | Respec: selecione 'Respec' + Enter (confirmação)")
    self.contents.draw_text(0, 168, 420, 24, "Esc: sair | Na confirmação: Enter=seleciona, Esc=cancela")
  end
end

class Window_RM_ConfirmYesNo < Window_Command
  def initialize
    super(160, ["Sim", "Não"])
    self.x = 240
    self.y = 80
    self.z = 9999
    self.visible = true
    self.active = true
  end
end

class Scene_RM_StatAllocation
  def initialize(actor)
    @actor = actor
  end

  def main
    @cmd = Window_RM_StatAlloc.new(@actor)
    @info = Window_RM_StatAllocInfo.new(@actor)
    @confirm_window = nil
    @pending_respec_cost = 0
    @last_cmd_index = @cmd.index
    @info.set_notice("") if @info.respond_to?(:set_notice)
    Graphics.transition
    loop do
      Graphics.update
      Input.update
      update
      break if $scene != self
    end
    Graphics.freeze
    @cmd.dispose
    @info.dispose
  end

  def update
    @cmd.update
    @confirm_window.update if @confirm_window != nil

    # Reset pending confirmation if selection changed
    if @last_cmd_index != @cmd.index
      if @confirm_window != nil
        @confirm_window.dispose
        @confirm_window = nil
        @cmd.active = true
      end
      @pending_respec_cost = 0
      @info.set_notice("") if @info.respond_to?(:set_notice)
      @last_cmd_index = @cmd.index
    end

    if Input.trigger?(Input::B)
      if @confirm_window != nil
        @confirm_window.dispose
        @confirm_window = nil
        @pending_respec_cost = 0
        @cmd.active = true
        @info.set_notice("Respec cancelado.") if @info.respond_to?(:set_notice)
        @info.refresh
        return
      end
      $scene = Scene_Map.new
      return
    end

    if Input.trigger?(Input::C)
      if @confirm_window != nil
        cost = @pending_respec_cost.to_i
        if @confirm_window.index == 0
          # Yes
          if cost > 0 && !(RM_StatAlloc.spend_s(cost) rescue false)
            @info.set_notice("Sem fundos: #{(RM_Currency.format_cost_s(cost) rescue "#{cost} S")}.") if @info.respond_to?(:set_notice)
            @confirm_window.dispose
            @confirm_window = nil
            @pending_respec_cost = 0
            @cmd.active = true
            @info.refresh
            return
          end

          RM_StatAlloc.respec_all(@actor)

          begin
            st = $game_system.rm_player_level_state
            st.respec_count = 0 if st.respec_count == nil
            st.respec_count += 1
          rescue
            # ignore
          end

          # Audit trail (RecentEvent)
          begin
            if defined?(RM_RecentEvents)
              RM_RecentEvents.push("EVT_PLAYER_RESPEC_STATALLOC", nil, 50)
            end
          rescue
            # ignore
          end

          @info.set_notice("Respec concluído! (-#{(RM_Currency.format_cost_s(cost) rescue "#{cost} S")})") if @info.respond_to?(:set_notice)
        else
          # No
          @info.set_notice("Respec cancelado.") if @info.respond_to?(:set_notice)
        end

        @confirm_window.dispose
        @confirm_window = nil
        @pending_respec_cost = 0
        @cmd.active = true
        @info.refresh
        return
      end

      cmd_name = @cmd.rm_command_name(@cmd.index) rescue nil

      if cmd_name == "Respec"
        st = $game_system.rm_player_level_state
        lvl = st.level rescue 1
        rc = RM_StatAlloc.ensure_respec_count(st) rescue 0
        cost = RM_StatAlloc.respec_cost_s(lvl, rc) rescue 0
        cost = cost.to_i
        cost = 0 if cost < 0

        @pending_respec_cost = cost

        if @confirm_window != nil
          @confirm_window.dispose
          @confirm_window = nil
        end
        @confirm_window = Window_RM_ConfirmYesNo.new
        @confirm_window.active = true
        @confirm_window.visible = true
        @cmd.active = false

        @info.set_notice("Confirmar Respec? #{(RM_Currency.format_cost_s(cost) rescue "#{cost} S")}") if @info.respond_to?(:set_notice)
        return
      end
      end

      # Default: allocate +1 to the selected stat
      key = RM_StatAlloc::STAT_KEYS[@cmd.index]
      RM_StatAlloc.allocate(key, 1, @actor)
      @info.refresh
      return
    end

  end
end

# --------------------
# Debug overlay (Scene_Map patch)
# --------------------
module RM_DebugOverlay_PlayerLevel
  SWITCH_ID = 902  # reserved for player level overlay
  @@sprite = nil
  @@bitmap = nil

  def self.enabled?
    return false if $game_switches == nil
    $game_switches[SWITCH_ID] == true
  end

  def self.ensure
    return if @@sprite != nil
    @@sprite = Sprite.new
    @@sprite.z = 9999
    @@sprite.x = 8
    @@sprite.y = 8
    @@bitmap = Bitmap.new(360, 96)
    @@sprite.bitmap = @@bitmap
  end

  def self.dispose
    if @@sprite != nil
      @@sprite.bitmap.dispose if @@sprite.bitmap != nil
      @@sprite.dispose
      @@sprite = nil
      @@bitmap = nil
    end
  end

  def self.update
    if !enabled?
      dispose
      return
    end
    ensure
    @@bitmap.clear
    st = $game_system.rm_player_level_state
    lvl = st.level
    tot = st.total_xp
    pts = st.unspent_main_stat_points
    hp = st.bonus_hp
    sp = st.bonus_sp
    @@bitmap.draw_text(0, 0, 360, 24, "LV #{lvl}  XP #{tot}  PTS #{pts}")
    @@bitmap.draw_text(0, 24, 360, 24, "Bonus HP +#{hp}  SP +#{sp}")
    @@bitmap.draw_text(0, 48, 360, 24, "Day #{RM_WorldTime.day}  Chapter #{RM_WorldTime.chapter}")
    @@bitmap.draw_text(0, 72, 360, 24, "Script: RM_StatAlloc.open_scene")
  end
end

class Scene_Map
  alias rm_dbg_plv_update update
  def update
    rm_dbg_plv_update
    RM_DebugOverlay_PlayerLevel.update
  end
end
