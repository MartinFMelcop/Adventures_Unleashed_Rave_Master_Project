# RM_FLAGS_EVENTS_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: Persist flags and recent events in save/load (Game_System).
# audience: AI-only (technical)
# ruby: RGSS / RPG Maker XP (Ruby 1.8)
#
# Tables used (copied into Data/RM_CSV/ at build time):
# - MEMORY_FLAGS.csv: FlagID,Scope,Name,Description,DefaultValue,TTL_Turns
# - RECENT_EVENTS.csv: EventID,Name,Description,TTL_Turns
#
# Design:
# - Flags can be GLOBAL (world/player), NPC (per NPC), RELATION (NPC<->player).
# - Recent events are recorded with TTL in turns (lightweight recency gate).
# - Persistence is automatic via Game_System serialization.

module RM_FlagsEvents
  CSV_ROOT = "Data/RM_CSV/"

  def self.read_csv_hashes(path)
    rows = []
    begin
      f = File.open(path, "rb")
    rescue
      return rows
    end
    header_line = f.gets
    if header_line == nil
      f.close
      return rows
    end
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

  def self.to_i_or_nil(s)
    return nil if s == nil
    s = s.to_s.strip
    return nil if s == ""
    # allow floats like "10.0"
    if s.index(".")
      return s.to_f.to_i
    end
    s.to_i
  end
end

class RM_FlagStore
  def initialize
    @turn = 0
    @defs_loaded = false
    @flag_defs = {}   # flag_id => { "Scope"=>..., "TTL"=>IntegerOrNil }
    @global = {}      # flag_id => { "v"=>true, "exp"=>IntegerOrNil }
    @npc = {}         # npc_id => { flag_id => entry }
    @rel = {}         # npc_id => { flag_id => entry }  (relation NPC<->player)
  end

  def load_defs
    return if @defs_loaded
    @defs_loaded = true
    @flag_defs = {}
    rows = RM_FlagsEvents.read_csv_hashes(RM_FlagsEvents::CSV_ROOT + "MEMORY_FLAGS.csv")
    rows.each do |r|
      fid = r["FlagID"]
      next if fid == nil || fid == ""
      scope = (r["Scope"] || "GLOBAL").strip
      ttl = RM_FlagsEvents.to_i_or_nil(r["TTL_Turns"])
      @flag_defs[fid] = {"Scope"=>scope, "TTL"=>ttl}
    end
  end

  def turn
    @turn
  end

  def tick_turn(n = 1)
    n = n.to_i
    n = 1 if n < 1
    @turn += n
    prune!
  end

  def prune!
    prune_map!(@global)
    @npc.keys.each { |k| prune_map!(@npc[k]) }
    @rel.keys.each { |k| prune_map!(@rel[k]) }
  end

  def prune_map!(h)
    return if h == nil
    h.keys.each do |fid|
      e = h[fid]
      next if e == nil
      exp = e["exp"]
      if exp != nil && exp <= @turn
        h.delete(fid)
      end
    end
  end

  def defn(flag_id)
    load_defs
    @flag_defs[flag_id]
  end

  def set(flag_id, value = true, npc_id = nil, scope = nil, ttl_turns = nil)
    return if flag_id == nil || flag_id == ""
    d = defn(flag_id)
    scope = scope || (d ? d["Scope"] : "GLOBAL")
    ttl = (ttl_turns != nil) ? ttl_turns.to_i : (d ? d["TTL"] : nil)
    exp = (ttl != nil) ? (@turn + ttl) : nil

    entry = {"v" => (value == true), "exp" => exp}
    case scope
    when "NPC"
      npc_id = npc_id || "NPC_UNKNOWN"
      @npc[npc_id] ||= {}
      @npc[npc_id][flag_id] = entry
    when "RELATION"
      npc_id = npc_id || "NPC_UNKNOWN"
      @rel[npc_id] ||= {}
      @rel[npc_id][flag_id] = entry
    else
      @global[flag_id] = entry
    end
    true
  end

  def clear(flag_id, npc_id = nil, scope = nil)
    return if flag_id == nil || flag_id == ""
    d = defn(flag_id)
    scope = scope || (d ? d["Scope"] : "GLOBAL")
    case scope
    when "NPC"
      npc_id = npc_id || "NPC_UNKNOWN"
      return false if @npc[npc_id] == nil
      @npc[npc_id].delete(flag_id)
    when "RELATION"
      npc_id = npc_id || "NPC_UNKNOWN"
      return false if @rel[npc_id] == nil
      @rel[npc_id].delete(flag_id)
    else
      @global.delete(flag_id)
    end
    true
  end

  def active_entry?(e)
    return false if e == nil
    return false unless e["v"] == true
    exp = e["exp"]
    return true if exp == nil
    exp > @turn
  end

  def has?(flag_id, npc_id = nil)
    return false if flag_id == nil || flag_id == ""
    # active in any relevant scope
    e = @global[flag_id]
    return true if active_entry?(e)

    if npc_id != nil
      h = @npc[npc_id]
      return true if h != nil && active_entry?(h[flag_id])
      r = @rel[npc_id]
      return true if r != nil && active_entry?(r[flag_id])
    end
    false
  end

  def flags_for(npc_id = nil)
    out = {}
    @global.keys.each do |fid|
      out[fid] = true if active_entry?(@global[fid])
    end
    if npc_id != nil
      h = @npc[npc_id]
      if h != nil
        h.keys.each { |fid| out[fid] = true if active_entry?(h[fid]) }
      end
      r = @rel[npc_id]
      if r != nil
        r.keys.each { |fid| out[fid] = true if active_entry?(r[fid]) }
      end
    end
    out
  end

  def debug_dump(npc_id = nil)
    f = flags_for(npc_id)
    keys = f.keys.sort
    keys.join(";")
  end
end

class RM_RecentEventStore
  def initialize
    @turn = 0
    @defs_loaded = false
    @event_defs = {}  # event_id => ttl
    @events = []      # [{ "id"=>..., "npc"=>..., "exp"=>... }]
  end

  def load_defs
    return if @defs_loaded
    @defs_loaded = true
    @event_defs = {}
    rows = RM_FlagsEvents.read_csv_hashes(RM_FlagsEvents::CSV_ROOT + "RECENT_EVENTS.csv")
    rows.each do |r|
      eid = r["EventID"]
      next if eid == nil || eid == ""
      ttl = RM_FlagsEvents.to_i_or_nil(r["TTL_Turns"])
      @event_defs[eid] = ttl
    end
  end

  def turn
    @turn
  end

  def tick_turn(n = 1)
    n = n.to_i
    n = 1 if n < 1
    @turn += n
    prune!
  end

  def prune!
    i = 0
    while i < @events.size
      e = @events[i]
      exp = e["exp"]
      if exp != nil && exp <= @turn
        @events.delete_at(i)
      else
        i += 1
      end
    end
  end

  def ttl_for(event_id)
    load_defs
    @event_defs[event_id]
  end

  def push(event_id, npc_id = nil, ttl_turns = nil)
    return false if event_id == nil || event_id == ""
    ttl = (ttl_turns != nil) ? ttl_turns.to_i : ttl_for(event_id)
    exp = (ttl != nil) ? (@turn + ttl) : nil
    @events << {"id"=>event_id, "npc"=>npc_id, "exp"=>exp}
    prune! if @events.size > 120
    true
  end

  def has?(event_id, npc_id = nil)
    return false if event_id == nil || event_id == ""
    @events.each do |e|
      next unless e["id"] == event_id
      exp = e["exp"]
      next if exp != nil && exp <= @turn
      if npc_id == nil || e["npc"] == nil || e["npc"] == npc_id
        return true
      end
    end
    false
  end


def clear(event_id, npc_id = nil)
  return false if event_id == nil || event_id == ""
  before = @events.size
  if npc_id == nil
    @events.delete_if { |e| e["id"] == event_id }
  else
    @events.delete_if { |e| e["id"] == event_id && e["npc"] == npc_id }
  end
  before != @events.size
end

  def events_for(npc_id = nil)
    out = {}
    @events.each do |e|
      exp = e["exp"]
      next if exp != nil && exp <= @turn
      if npc_id == nil || e["npc"] == nil || e["npc"] == npc_id
        out[e["id"]] = true
      end
    end
    out
  end

  def debug_dump(npc_id = nil)
    e = events_for(npc_id)
    e.keys.sort.join(";")
  end
end

# --- Game_System integration (persistence via save/load) ---

class Game_System
  attr_accessor :rm_flag_store
  attr_accessor :rm_event_store

  alias rm_flags_events_initialize initialize
  def initialize
    rm_flags_events_initialize
    rm_init_flags_events
  end

  def rm_init_flags_events
    @rm_flag_store = RM_FlagStore.new if @rm_flag_store == nil
    @rm_event_store = RM_RecentEventStore.new if @rm_event_store == nil
  end

  # Back-compat (global view only). Prefer rm_flags_for(npc_id).
  def rm_flags
    rm_init_flags_events
    @rm_flag_store.flags_for(nil)
  end

  def rm_flags_for(npc_id)
    rm_init_flags_events
    @rm_flag_store.flags_for(npc_id)
  end

  def rm_recent_events
    rm_init_flags_events
    @rm_event_store.events_for(nil)
  end

  def rm_recent_events_for(npc_id)
    rm_init_flags_events
    @rm_event_store.events_for(npc_id)
  end
end

# --- Convenience API (Script Calls) ---

module RM_Flags
  def self.set(flag_id, value = true, npc_id = nil, scope = nil, ttl_turns = nil)
    return false unless defined?($game_system)
    $game_system.rm_init_flags_events
    $game_system.rm_flag_store.set(flag_id, value, npc_id, scope, ttl_turns)
  end

  def self.clear(flag_id, npc_id = nil, scope = nil)
    return false unless defined?($game_system)
    $game_system.rm_init_flags_events
    $game_system.rm_flag_store.clear(flag_id, npc_id, scope)
  end

  def self.has?(flag_id, npc_id = nil)
    return false unless defined?($game_system)
    $game_system.rm_init_flags_events
    $game_system.rm_flag_store.has?(flag_id, npc_id)
  end

  def self.tick_turn(n = 1)
    return false unless defined?($game_system)
    $game_system.rm_init_flags_events
    $game_system.rm_flag_store.tick_turn(n)
    true
  end
end

module RM_RecentEvents
  def self.push(event_id, npc_id = nil, ttl_turns = nil)
    return false unless defined?($game_system)
    $game_system.rm_init_flags_events
    $game_system.rm_event_store.push(event_id, npc_id, ttl_turns)
  end

def self.clear(event_id, npc_id = nil)
  return false unless defined?($game_system)
  $game_system.rm_init_flags_events
  $game_system.rm_event_store.clear(event_id, npc_id)
end

  def self.has?(event_id, npc_id = nil)
    return false unless defined?($game_system)
    $game_system.rm_init_flags_events
    $game_system.rm_event_store.has?(event_id, npc_id)
  end

  def self.tick_turn(n = 1)
    return false unless defined?($game_system)
    $game_system.rm_init_flags_events
    $game_system.rm_event_store.tick_turn(n)
    true
  end
end
