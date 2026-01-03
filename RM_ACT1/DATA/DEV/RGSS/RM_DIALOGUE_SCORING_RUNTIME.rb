# RM_DIALOGUE_SCORING_RUNTIME.rb
# AI-only / RM Project (Rave Masters)
# Purpose: Deterministic dialogue variant selection (intent + tags + state + relations + personality axes)
# Engine: RPG Maker XP / RGSS (Ruby 1.8)
#
# Notes:
# - No generative text. Chooses from DIALOGUE_VARIANTS.csv.
# - ConditionsExpr is intentionally simple (supports &, |, ==, !=, <, <=, >, >=, HasTag(X)=true/false, HasFlag(X)=true/false).
# - This runtime is "data-first": canonical truth is DATA/*. At build time, CSVs are expected to be deployed under Data/RM_CSV/.
#
# Optional debug:
# - Set $game_switches[RM::SW_DEBUG_DIALOGUE] = true to print scoring breakdown to message.

module RM
  # Reserved switch/variable IDs (optional). Do not collide with project ranges if you allocate them later.
  SW_DEBUG_DIALOGUE = 901
  SW_DEBUG_DIALOGUE_TRACE = 902

  # CSV location at runtime (build pipeline responsibility)
  CSV_ROOT = "Data/RM_CSV/"

  SCORE_SCALE_AXIS   = 100.0
  SCORE_SCALE_STATE  = 100.0
  SCORE_SCALE_REL    = 100.0
  SCORE_SCALE_NORM   = 100.0

  # Axis key mapping (weight keys -> profile column keys)
  AXIS_KEY_MAP = {
    "EMPATHY"         => "Axis_EMPATHY",
    "ASSERTIVENESS"   => "Axis_ASSERTIVENESS",
    "ORDER_NEED"      => "Axis_ORDER_NEED",
    "NOVELTY_SEEKING" => "Axis_NOVELTY",
    "RISK_APPETITE"   => "Axis_RISK",
    "PATIENCE"        => "Axis_PATIENCE",
    "VOLATILITY"      => "Axis_VOLATILITY",
    "BASE_TRUST"      => "Axis_BASE_TRUST",
    "PRAGMATISM"      => "Axis_PRAGMATISM",
    "DIRECTNESS"      => "Axis_DIRECTNESS"
  }

  def self.clamp(v, lo, hi)
    return lo if v < lo
    return hi if v > hi
    v
  end

  # Minimal CSV parser with quoted field support (Ruby 1.8 friendly)
  module CSVLite
    def self.read_table(relpath)
      path = RM::CSV_ROOT + relpath
      return nil unless File.exist?(path)
      parse(File.read(path))
    end

    # Returns [headers:Array<String>, rows:Array<Array<String>>]
    def self.parse(text)
      text = text.gsub("\r\n", "\n").gsub("\r", "\n")
      rows = []
      row = []
      field = ""
      in_quotes = false
      i = 0
      while i < text.size
        ch = text[i]
        if in_quotes
          if ch == '"'
            if i + 1 < text.size && text[i + 1] == '"'
              field << '"'
              i += 1
            else
              in_quotes = false
            end
          else
            field << ch
          end
        else
          if ch == '"'
            in_quotes = true
          elsif ch == ','
            row << field
            field = ""
          elsif ch == "\n"
            row << field
            rows << row
            row = []
            field = ""
          else
            field << ch
          end
        end
        i += 1
      end
      # last field
      row << field
      rows << row unless row.size == 1 && row[0] == "" && rows.size > 0
      headers = rows.shift
      [headers, rows]
    end
  end



  # ConditionsExpr: tiny parser/evaluator (supports &, |, parentheses, comparisons, HasTag/HasFlag)
  # This replaces the older split-based evaluator and avoids eval().
  module ConditionsExpr
    def self.tokenize(s)
      s = "" if s == nil
      out = []
      i = 0
      while i < s.length
        ch = s[i,1]
        if ch =~ /\s/
          i += 1
          next
        end
        two = s[i,2]
        if two == "==" || two == "!=" || two == "<=" || two == ">="
          out << [two, two]
          i += 2
          next
        end
        if ch == "(" || ch == ")" || ch == "&" || ch == "|" || ch == "<" || ch == ">" || ch == "="
          out << [ch, ch]
          i += 1
          next
        end
        if ch =~ /[A-Za-z0-9_\-@:\.]/
          j = i
          while j < s.length && s[j,1] =~ /[A-Za-z0-9_\-@:\.]/
            j += 1
          end
          out << [:id, s[i, j-i]]
          i = j
          next
        end
        # unknown char: skip
        i += 1
      end
      out
    end

    class Parser
      def initialize(tokens)
        @t = tokens
        @i = 0
      end

      def peek
        return nil if @i >= @t.length
        @t[@i]
      end

      def eat(type = nil)
        tok = peek
        return nil if tok == nil
        if type != nil && tok[0] != type
          return nil
        end
        @i += 1
        tok
      end

      def parse
        parse_or
      end

      def parse_or
        left = parse_and
        while true
          tok = peek
          break if tok == nil
          if tok[0] == "|"
            eat("|")
            right = parse_and
            left = [:or, left, right]
          else
            break
          end
        end
        left
      end

      def parse_and
        left = parse_primary
        while true
          tok = peek
          break if tok == nil
          if tok[0] == "&"
            eat("&")
            right = parse_primary
            left = [:and, left, right]
          else
            break
          end
        end
        left
      end

      def parse_primary
        tok = peek
        return [:lit, true] if tok == nil
        if tok[0] == "("
          eat("(")
          node = parse_or
          eat(")")
          return node
        end
        parse_atom
      end

      def parse_atom
        tok = peek
        return [:lit, true] if tok == nil

        if tok[0] == :id && (tok[1] == "HasTag" || tok[1] == "HasFlag" || tok[1] == "HasRecentEvent")
          fn = tok[1]
          eat(:id)
          eat("(")
          arg_tok = eat(:id)
          arg = arg_tok ? arg_tok[1] : ""
          eat(")")
          want = true
          eq_tok = peek
          if eq_tok != nil && (eq_tok[0] == "=" || eq_tok[0] == "==")
            eat(eq_tok[0])
            b = eat(:id)
            want = (b && b[1] && b[1].downcase == "true")
          end
          if fn == "HasTag"
            return [:hastag, arg, want]
          elsif fn == "HasFlag"
            return [:hasflag, arg, want]
          else
            return [:hasrecentevent, arg, want]
          end
        end

        lhs_tok = eat(:id)
        lhs = lhs_tok ? lhs_tok[1] : ""
        op_tok = peek
        return [:lit, false] if op_tok == nil

        op = nil
        if op_tok[0] == "==" || op_tok[0] == "!=" || op_tok[0] == "<=" || op_tok[0] == ">=" || op_tok[0] == "<" || op_tok[0] == ">"
          op = op_tok[0]
          eat(op_tok[0])
        elsif op_tok[0] == "="
          op = "=="
          eat("=")
        else
          # unexpected: consume and fail
          eat(op_tok[0])
          return [:lit, false]
        end

        rhs_tok = eat(:id)
        rhs = rhs_tok ? rhs_tok[1] : ""
        [:cmp, lhs, op, rhs]
      end
    end

    def self.parse(expr)
      tokens = tokenize(expr)
      Parser.new(tokens).parse
    end

    def self.resolve_key(key, state, rel)
      return nil if key == nil || key == ""
      if rel != nil && rel[key] != nil
        return rel[key]
      end
      if state != nil && state[key] != nil
        return state[key]
      end
      if state != nil && state[key + "_0_100"] != nil
        return state[key + "_0_100"]
      end
      nil
    end

    def self.eval_cmp(key, op, rhs, state, rel)
      lhs_raw = resolve_key(key, state, rel)
      return false if lhs_raw == nil
      lhs = lhs_raw.to_s
      rhs_s = rhs.to_s

      if lhs =~ /^-?\d+$/ && rhs_s =~ /^-?\d+$/
        lv = lhs.to_i
        rv = rhs_s.to_i
        case op
        when "==" then return lv == rv
        when "!=" then return lv != rv
        when "<=" then return lv <= rv
        when ">=" then return lv >= rv
        when "<"  then return lv < rv
        when ">"  then return lv > rv
        else return false
        end
      else
        case op
        when "==" then return lhs == rhs_s
        when "!=" then return lhs != rhs_s
        else return false
        end
      end
    end

    def self.eval_node(node, state, rel, tagset, flags, trace, npc_id = nil)
      t = node[0]
      if t == :or
        a = eval_node(node[1], state, rel, tagset, flags, trace, npc_id)
        return true if a
        return eval_node(node[2], state, rel, tagset, flags, trace, npc_id)
      elsif t == :and
        a = eval_node(node[1], state, rel, tagset, flags, trace, npc_id)
        return false unless a
        return eval_node(node[2], state, rel, tagset, flags, trace, npc_id)
      elsif t == :cmp
        res = eval_cmp(node[1], node[2], node[3], state, rel)
        trace << "#{node[1]}#{node[2]}#{node[3]} => #{res}" if trace != nil
        return res
      elsif t == :hastag
        has = (tagset != nil && tagset[node[1]] == true)
        res = (has == node[2])
        trace << "HasTag(#{node[1]})=#{node[2] ? 'true' : 'false'} => #{res}" if trace != nil
        return res
      elsif t == :hasflag
        has = (flags != nil && flags[node[1]] == true)
        res = (has == node[2])
        trace << "HasFlag(#{node[1]})=#{node[2] ? 'true' : 'false'} => #{res}" if trace != nil
        return res
      elsif t == :hasrecentevent
        eid = node[1]
        if eid != nil && eid.to_s =~ /^(.+?)[@:](\d+)$/
          eid = $1
        end
        has = false
        if defined?(RM_RecentEvents)
          begin
            has = RM_RecentEvents.has?(eid, npc_id)
          rescue
            has = false
          end
        end
        res = (has == node[2])
        trace << "HasRecentEvent(#{eid})=#{node[2] ? 'true' : 'false'} => #{res}" if trace != nil
        return res
      elsif t == :lit
        return (node[1] == true)
      else
        return false
      end
    end

    def self.fallback_eval(expr, state, rel, tagset, flags, trace, npc_id = nil)
      # older behavior: OR by '|', AND by '&' (no parentheses)
      or_parts = expr.split("|").map { |s| s.strip }.reject { |s| s == "" }
      or_parts.each do |part|
        and_parts = part.split("&").map { |s| s.strip }.reject { |s| s == "" }
        ok = true
        and_parts.each do |cond|
          res = eval_atom_string(cond, state, rel, tagset, flags, npc_id)
          trace << "#{cond} => #{res}" if trace != nil
          ok = false unless res
          break unless ok
        end
        return true if ok
      end
      false
    end

    def self.eval_atom_string(cond, state, rel, tagset, flags, npc_id = nil)
      if cond.index("HasTag(") == 0
        m = cond.match(/^HasTag\(([A-Za-z0-9_\-@:\.]+)\)\s*(==|=)\s*(true|false)$/i)
        return false if m == nil
        key = m[1]
        want = (m[3].downcase == "true")
        has = (tagset != nil && tagset[key] == true)
        return (has == want)
      end
      if cond.index("HasFlag(") == 0
        m = cond.match(/^HasFlag\(([A-Za-z0-9_\-@:\.]+)\)\s*(==|=)\s*(true|false)$/i)
        return false if m == nil
        key = m[1]
        want = (m[3].downcase == "true")
        has = (flags != nil && flags[key] == true)
        return (has == want)
      end
      if cond.index("HasRecentEvent(") == 0
        m = cond.match(/^HasRecentEvent\(([A-Za-z0-9_\-@:\.]+)\)\s*(==|=)\s*(true|false)$/i)
        return false if m == nil
        key = m[1]
        key = $1 if key =~ /^(.+?)[@:](\d+)$/
        want = (m[3].downcase == "true")
        has = false
        if defined?(RM_RecentEvents)
          begin
            has = RM_RecentEvents.has?(key, npc_id)
          rescue
            has = false
          end
        end
        return (has == want)
      end
      m = cond.match(/^([A-Za-z0-9_\-@:\.]+)\s*(==|!=|<=|>=|<|>)\s*([A-Za-z0-9_\-@:\.]+)$/)
      return false if m == nil
      eval_cmp(m[1], m[2], m[3], state, rel)
    end

    def self.eval(expr, state, rel, tagset, flags, trace = nil, npc_id = nil)
      expr = "" if expr == nil
      expr = expr.strip
      return true if expr == ""
      begin
        node = parse(expr)
        eval_node(node, state, rel, tagset, flags, trace, npc_id)
      rescue
        fallback_eval(expr, state, rel, tagset, flags, trace, npc_id)
      end
    end

    def self.count_atoms(node)
      t = node[0]
      if t == :or || t == :and
        return count_atoms(node[1]) + count_atoms(node[2])
      elsif t == :cmp || t == :hastag || t == :hasflag || t == :hasrecentevent
        return 1
      else
        return 0
      end
    end

    def self.specificity(expr)
      expr = "" if expr == nil
      expr = expr.strip
      return 0 if expr == ""
      begin
        node = parse(expr)
        count_atoms(node)
      rescue
        rough = expr.gsub("|", "&")
        rough.split("&").map { |s| s.strip }.reject { |s| s == "" }.length
      end
    end
  end

  module DialogueScoring
    @loaded = false
    @variants = []      # array of hashes
    @npc_profile = {}   # IdNPC -> hash
    @npc_state = {}     # IdNPC -> hash
    @npc_rel_player = {} # IdNPC -> hash
    @faction_norms = {} # FactionID -> NormID -> value
    @last_debug = nil

    def self.last_debug
      @last_debug
    end

    def self.ensure_loaded!
      return if @loaded
      load_profiles!
      load_state!
      load_relations!
      load_faction_norms!
      load_variants!
      @loaded = true
    end

    def self.load_profiles!
      h, rows = CSVLite.read_table("DEV/NPC_PROFILE.csv")
      return if h.nil?
      idx = {}
      h.each_with_index { |name, i| idx[name] = i }
      rows.each do |r|
        id = r[idx["IdNPC"]]
        next if id.nil? || id == ""
        @npc_profile[id] = {}
        h.each do |col|
          @npc_profile[id][col] = r[idx[col]]
        end
      end
    end

    def self.load_state!
      h, rows = CSVLite.read_table("DEV/NPC_STATE.csv")
      return if h.nil?
      idx = {}
      h.each_with_index { |name, i| idx[name] = i }
      rows.each do |r|
        id = r[idx["IdNPC"]]
        next if id.nil? || id == ""
        @npc_state[id] = {}
        h.each do |col|
          @npc_state[id][col] = r[idx[col]]
        end
      end
    end

    def self.load_relations!
      h, rows = CSVLite.read_table("DEV/NPC_RELATIONS.csv")
      return if h.nil?
      idx = {}
      h.each_with_index { |name, i| idx[name] = i }
      rows.each do |r|
        source = r[idx["SourceIdNPC"]]
        ttype  = r[idx["TargetType"]]
        tid    = r[idx["TargetID"]]
        next unless ttype == "PLAYER" && tid == "PLAYER"
        @npc_rel_player[source] = {
          "Trust_Player"   => r[idx["Trust_0_100"]],
          "Respect_Player" => r[idx["Respect_0_100"]],
          "Debt_Player"    => r[idx["Debt"]]
        }
      end
    end

    def self.load_faction_norms!
      h, rows = CSVLite.read_table("CORE/FACTION_NORMS.csv")
      return if h.nil?
      idx = {}
      h.each_with_index { |name, i| idx[name] = i }
      rows.each do |r|
        fac = r[idx["FactionID"]]
        norm = r[idx["NormID"]]
        val = r[idx["Value_0_100"]]
        next if fac.nil? || fac == "" || norm.nil? || norm == ""
        @faction_norms[fac] ||= {}
        @faction_norms[fac][norm] = val
      end
    end

    def self.load_variants!
      h, rows = CSVLite.read_table("DEV/DIALOGUE_VARIANTS.csv")
      return if h.nil?
      idx = {}
      h.each_with_index { |name, i| idx[name] = i }
      rows.each do |r|
        vid = r[idx["VariantID"]]
        next if vid.nil? || vid == ""
        v = {}
        h.each { |col| v[col] = r[idx[col]] }
        @variants << v
      end
    end

    
    def self.condition_specificity(expr)
      RM::ConditionsExpr.specificity(expr)
    end

# Public entrypoint: choose a variant text and apply deltas.
    # tags: Array<String>
    # flags: Hash<String, true/false> (optional). If nil, uses $game_system.rm_flags (if present).
    def self.say(npc_id, intent_id, tags = [], flags = nil)
      ensure_loaded!
      # TTL tick (align with QA runner semantics: decay happens between dialogue turns)
      begin
        RM_Flags.tick_turn(1) if defined?(RM_Flags)
      rescue
        # ignore
      end
      begin
        RM_RecentEvents.tick_turn(1) if defined?(RM_RecentEvents)
      rescue
        # ignore
      end
      v = choose_variant(npc_id, intent_id, tags, flags)
      return "" if v.nil?
      apply_deltas!(npc_id, v, flags)
      v["Text"] || ""
    end

    def self.choose_variant(npc_id, intent_id, tags = [], flags = nil)
      ensure_loaded!
      profile = @npc_profile[npc_id] || {}
      state = @npc_state[npc_id] || {}
      rel = @npc_rel_player[npc_id] || {"Trust_Player"=>"50","Respect_Player"=>"50","Debt_Player"=>"0"}

            if flags == nil
        if defined?($game_system) && $game_system.respond_to?(:rm_flags_for)
          flags = $game_system.rm_flags_for(npc_id)
        elsif defined?($game_system) && $game_system.respond_to?(:rm_flags)
          flags = $game_system.rm_flags
        else
          flags = {}
        end
      end
        recent_events = _parse_list(idx["RecentEventsTrue"] ? r[idx["RecentEventsTrue"]] : "")
        # preload recent events for this NPC (test harness only)
        if recent_events && recent_events.size > 0 && defined?(RM_RecentEvents)
          begin
            recent_events.each { |e| RM_RecentEvents.push(e, npc_id, nil) }
          rescue
            # ignore
          end
        end

      tagset = {}
      tags.each { |t| tagset[t] = true }

      candidates = []
      @variants.each do |v|
        next unless v["IntentID"] == intent_id
        # scope filter: GLOBAL or NPC match
        st = v["ScopeType"]
        sid = v["ScopeID"]
        ok_scope = (st == "GLOBAL") || (st == "NPC" && sid == npc_id)
        next unless ok_scope

        expr = v["ConditionsExpr"]
        next if expr && expr != "" && !eval_condition(expr, state, rel, tagset, flags, nil, npc_id)
        candidates << v
      end

      return nil if candidates.empty?

      best = nil
      best_score = -1_000_000.0
      best_pri = -1_000_000
      best_spec = -1
      debug_rows = []

      candidates.each do |v|
        score, breakdown = score_variant(v, profile, state, rel, npc_id)
        pri = (v["Priority"] || "0").to_i
        spec = condition_specificity(v["ConditionsExpr"])
        # tie-breakers: score -> specificity -> priority -> VariantID
        vid = v["VariantID"] || ""
        best_vid = best ? (best["VariantID"] || "") : ""
        if best.nil? ||
           score > best_score ||
           (score == best_score && spec > best_spec) ||
           (score == best_score && spec == best_spec && pri > best_pri) ||
           (score == best_score && spec == best_spec && pri == best_pri && vid < best_vid)
          best = v
          best_score = score
          best_pri = pri
          best_spec = spec
        end
        debug_rows << breakdown
      end

      @last_debug = {
        "npc_id" => npc_id,
        "intent_id" => intent_id,
        "candidates" => debug_rows.sort { |a,b| b["score"] <=> a["score"] }
      }

      if defined?($game_switches) && $game_switches[RM::SW_DEBUG_DIALOGUE_TRACE] && best != nil
        trace = []
        expr = best["ConditionsExpr"]
        eval_condition(expr, state, rel, tagset, flags, trace, npc_id) if expr && expr != ""
        @last_debug["selected_variant_id"] = best["VariantID"]
        @last_debug["selected_conditions_expr"] = expr
        @last_debug["selected_conditions_trace"] = trace
      end

      if defined?($game_switches) && $game_switches[RM::SW_DEBUG_DIALOGUE]
        msg = "[DIALOGUE DEBUG] NPC=#{npc_id} INTENT=#{intent_id}\n"
        @last_debug["candidates"][0,5].each do |b|
          msg += "#{b["variant_id"]} score=#{b["score"].to_i} (axis=#{b["axis"].to_i} state=#{b["state"].to_i} rel=#{b["rel"].to_i})\n"
        end
        if defined?($game_switches) && $game_switches[RM::SW_DEBUG_DIALOGUE_TRACE] && @last_debug["selected_conditions_trace"]
          msg += "Selected=#{@last_debug["selected_variant_id"]} ConditionsExpr=#{@last_debug["selected_conditions_expr"]}\n"
          @last_debug["selected_conditions_trace"][0,25].each do |t|
            msg += "  #{t}\n"
          end
        end

        $game_message.add(msg) if defined?($game_message)
      end

      best
    end

    def self.score_variant(v, profile, state, rel, npc_id)
      base = (v["BaseScore"] || "0").to_f

      axis_sum = score_weights(v["AxisWeights"], profile, :axis)
      state_sum = score_weights(v["StateWeights"], state, :state, rel)
      rel_sum = score_weights(v["RelationWeights"], rel, :rel)
      norm_sum = score_norm_weights(v["NormWeights"], profile)

      score = base + axis_sum + state_sum + rel_sum + norm_sum
      breakdown = {
        "variant_id" => v["VariantID"],
        "score" => score,
        "base" => base,
        "axis" => axis_sum,
        "state" => state_sum,
        "rel" => rel_sum,
        "norm" => norm_sum,
        "priority" => (v["Priority"] || "0").to_i
      }
      [score, breakdown]
    end

    # kind: :axis, :state, :rel
    def self.score_weights(weights_str, source_hash, kind, rel_hash=nil)
      return 0.0 if weights_str.nil? || weights_str == ""
      parts = weights_str.split("|")
      sum = 0.0
      parts.each do |p|
        next if p.nil? || p == ""
        kv = p.split(":")
        next unless kv.size == 2
        key = kv[0]
        w = kv[1].to_f

        if kind == :axis
          col = RM::AXIS_KEY_MAP[key]
          next if col.nil?
          v = (source_hash[col] || "50").to_f
          scaled = (v - 50.0) / 50.0
          sum += scaled * w * RM::SCORE_SCALE_AXIS
        elsif kind == :state
          # Some state weights may refer to relations (Trust_Player etc)
          if key.index("Trust_") == 0 || key.index("Respect_") == 0 || key.index("Debt_") == 0
            v = ((rel_hash || {})[key] || "0").to_f
            scaled = v / 100.0
            sum += scaled * w * RM::SCORE_SCALE_REL
          else
            v = (source_hash[key] || source_hash[key + "_0_100"] || "0").to_f
            # Stress/Fear are 0..100, scale 0..1
            scaled = v / 100.0
            sum += scaled * w * RM::SCORE_SCALE_STATE
          end
        elsif kind == :rel
          v = (source_hash[key] || "0").to_f
          scaled = (key == "Debt_Player") ? v : (v / 100.0)
          sum += scaled * w * RM::SCORE_SCALE_REL
        end
      end
      sum
    end

    def self.score_norm_weights(weights_str, profile)
      return 0.0 if weights_str.nil? || weights_str == ""
      fac = profile["FactionID"]
      return 0.0 if fac.nil? || fac == ""
      norms = @faction_norms[fac] || {}
      sum = 0.0
      weights_str.split("|").each do |p|
        kv = p.split(":")
        next unless kv.size == 2
        key = kv[0]
        w = kv[1].to_f
        v = (norms[key] || "50").to_f
        scaled = (v - 50.0) / 50.0
        sum += scaled * w * RM::SCORE_SCALE_NORM
      end
      sum
    end

    # ConditionsExpr evaluation (simple grammar)
    def self.eval_condition(expr, state, rel, tagset, flags, trace = nil, npc_id = nil)
      return true if expr == nil || expr.strip == ""
      RM::ConditionsExpr.eval(expr, state, rel, tagset, flags, trace, npc_id)
    end

    # Back-compat: keep eval_atom for older callers, but implement via ConditionsExpr fallback.
    def self.eval_atom(cond, state, rel, tagset, flags, npc_id = nil)
      return RM::ConditionsExpr.eval_atom_string(cond, state, rel, tagset, flags, npc_id)
    end

        def self.apply_deltas!(npc_id, variant, flags)
      ensure_loaded!
            if flags == nil
        if defined?($game_system) && $game_system.respond_to?(:rm_flags_for)
          flags = $game_system.rm_flags_for(npc_id)
        elsif defined?($game_system) && $game_system.respond_to?(:rm_flags)
          flags = $game_system.rm_flags
        else
          flags = {}
        end
      end

      st = @npc_state[npc_id] || {"Stress_0_100"=>"0", "Fear_0_100"=>"0", "Mood"=>"NEUTRAL", "OutburstCooldown"=>"0"}

      ds = (variant["DeltaStress"] || "0").to_i
      df = (variant["DeltaFear"] || "0").to_i
      st["Stress_0_100"] = RM.clamp(st["Stress_0_100"].to_i + ds, 0, 100).to_s
      st["Fear_0_100"] = RM.clamp(st["Fear_0_100"].to_i + df, 0, 100).to_s

      mood = variant["SetMood"]
      st["Mood"] = mood if mood && mood != ""

      # Relations (player)
      rel = @npc_rel_player[npc_id] || {"Trust_Player"=>"50","Respect_Player"=>"50","Debt_Player"=>"0"}
      dt = (variant["DeltaTrust_Player"] || "0").to_i
      dr = (variant["DeltaRespect_Player"] || "0").to_i
      dd = (variant["DeltaDebt_Player"] || "0").to_i
      rel["Trust_Player"] = RM.clamp(rel["Trust_Player"].to_i + dt, 0, 100).to_s
      rel["Respect_Player"] = RM.clamp(rel["Respect_Player"].to_i + dr, 0, 100).to_s
      rel["Debt_Player"] = (rel["Debt_Player"].to_i + dd).to_s

      @npc_state[npc_id] = st
      @npc_rel_player[npc_id] = rel
      # Flag/Event operations (PERSISTENT)
      # - AddFlags: pipe-separated list (FLAG|FLAG2@TTL|...)
      # - AddFlags_TTL_Turns: optional default TTL override (applies when token has no @TTL)
      # - ClearFlags: pipe-separated list (FLAG|FLAG2|...)
      # - AddRecentEvent: pipe-separated list (EVT|EVT2@TTL|...)
      # - AddRecentEvent_TTL_Turns: optional default TTL override
      parse_id_ttl = lambda do |tok|
        t = (tok || "").to_s.strip
        return [nil, nil] if t == ""
        if t =~ /^(.+?)[@:](\d+)$/
          return [$1.strip, $2.to_i]
        end
        [t, nil]
      end

      # Add flags (PERSISTENT)
add_flags = variant["AddFlags"]
default_flag_ttl = variant["AddFlags_TTL_Turns"]
default_flag_ttl = (default_flag_ttl && default_flag_ttl.strip != "") ? default_flag_ttl.to_i : nil

# Token grammar:
#   FLAG_ID[=true|false][@TTL]
# Examples:
#   FLAG_X
#   FLAG_X@2
#   FLAG_X=false
#   FLAG_X=false@3
parse_flag_token = lambda do |tok|
  t = (tok || "").to_s.strip
  return [nil, nil, nil] if t == ""
  ttl = nil
  if t =~ /^(.+?)[@:](\d+)$/
    t = $1.strip
    ttl = $2.to_i
  end
  val = true
  if t =~ /^(.+?)=(true|false)$/i
    t = $1.strip
    val = ($2.downcase == "true")
  end
  [t, val, ttl]
end

if add_flags && add_flags != ""
  add_flags.split("|").each do |tok|
    fid, val, ttl_tok = parse_flag_token.call(tok)
    next if fid == nil || fid == ""
    ttl = ttl_tok || default_flag_ttl

    if defined?(RM_Flags) && defined?($game_system) && $game_system.respond_to?(:rm_flag_store)
      begin
        $game_system.rm_init_flags_events if $game_system.respond_to?(:rm_init_flags_events)
        d = nil
        begin
          store = $game_system.rm_flag_store
          d = store.defn(fid) if store && store.respond_to?(:defn)
        rescue
          d = nil
        end
        scope = d ? nil : "NPC"
        if val
          RM_Flags.set(fid, true, npc_id, scope, ttl)
          flags[fid] = true if flags != nil
        else
          RM_Flags.clear(fid, npc_id, scope)
          flags.delete(fid) if flags != nil
        end
      rescue
        # ignore persistence errors
      end
    else
      # local-only fallback
      if val
        flags[fid] = true if flags != nil
      else
        flags.delete(fid) if flags != nil
      end
    end
  end
end

# Clear flags (PERSISTENT)
clear_flags = variant["ClearFlags"]
if clear_flags && clear_flags != ""
  clear_flags.split("|").each do |tok|
    fid = (tok || "").to_s.strip
    next if fid == nil || fid == ""
    if defined?(RM_Flags) && defined?($game_system) && $game_system.respond_to?(:rm_flag_store)
      begin
        $game_system.rm_init_flags_events if $game_system.respond_to?(:rm_init_flags_events)
        d = nil
        begin
          store = $game_system.rm_flag_store
          d = store.defn(fid) if store && store.respond_to?(:defn)
        rescue
          d = nil
        end
        scope = d ? nil : "NPC"
        RM_Flags.clear(fid, npc_id, scope)
      rescue
        # ignore
      end
    end
    flags.delete(fid) if flags != nil
  end
end

# Add recent events (PERSISTENT)
      add_events = variant["AddRecentEvent"]
      default_evt_ttl = variant["AddRecentEvent_TTL_Turns"]
      default_evt_ttl = (default_evt_ttl && default_evt_ttl.strip != "") ? default_evt_ttl.to_i : nil
      if add_events && add_events != ""
        add_events.split("|").each do |tok|
          eid, ttl_tok = parse_id_ttl.call(tok)
          next if eid == nil || eid == ""
          ttl = ttl_tok || default_evt_ttl

          if defined?(RM_RecentEvents) && defined?($game_system) && $game_system.respond_to?(:rm_event_store)
            begin
              RM_RecentEvents.push(eid, npc_id, ttl)
            rescue
              # ignore
            end
          end
        end
      end

# Clear recent events (PERSISTENT)
clear_events = variant["ClearRecentEvent"]
if clear_events && clear_events != ""
  clear_events.split("|").each do |tok|
    eid = (tok || "").to_s.strip
    next if eid == nil || eid == ""
    if defined?(RM_RecentEvents) && defined?($game_system) && $game_system.respond_to?(:rm_event_store)
      begin
        $game_system.rm_init_flags_events if $game_system.respond_to?(:rm_init_flags_events)
        RM_RecentEvents.clear(eid, npc_id)
      rescue
        # ignore
      end
    end
  end
end
      true
    end
    # --- QA/Test harness ----------------------------------------------------
    # Script calls:
    #   RM::DialogueScoring.run_tests_dialogue_scoring()
    #   RM::DialogueScoring.run_scenarios_dialogue()
    #
    # Uses CSVs in QA/:
    #   QA/TEST_DIALOGUE_SCORING_RUNTIME.csv
    #   QA/TEST_SCENARIOS_DIALOGUE.csv

    def self._parse_list(str)
      return [] if str == nil
      str.to_s.split(/[\;\|,]/).map { |s| s.strip }.reject { |s| s == "" }
    end

    def self._inject_pre(state, rel, stress, mood, fear, trust)
      state["Stress_0_100"] = stress.to_s if stress != nil && stress != ""
      state["Mood"] = mood.to_s if mood != nil && mood != ""
      state["Fear_0_100"] = fear.to_s if fear != nil && fear != ""
      rel["Trust_Player"] = trust.to_s if trust != nil && trust != ""
    end

    def self.run_tests_dialogue_scoring(show_message = true)
      ensure_loaded!
      h, rows = CSVLite.read_table("QA/TEST_DIALOGUE_SCORING_RUNTIME.csv")
      return [] if h == nil || rows == nil

      idx = {}
      h.each_with_index { |name, i| idx[name] = i }

      results = []
      pass = 0
      fail = 0

      rows.each do |r|
        tid = (idx["TestID"] ? (r[idx["TestID"]] || "") : "")
        npc_id = (idx["NPCID"] ? (r[idx["NPCID"]] || "") : "")
        intent_id = (idx["IntentID"] ? (r[idx["IntentID"]] || "") : "")

        tags = _parse_list(idx["Tags"] ? r[idx["Tags"]] : "")
        flags = {}
        _parse_list(idx["FlagsTrue"] ? r[idx["FlagsTrue"]] : "").each { |f| flags[f] = true }

        state = (@npc_state[npc_id] || {"Stress_0_100"=>"0","Fear_0_100"=>"0","Mood"=>"NEUTRAL","OutburstCooldown"=>"0"}).dup
        rel = (@npc_rel_player[npc_id] || {"Trust_Player"=>"50","Respect_Player"=>"50","Debt_Player"=>"0"}).dup

        _inject_pre(state, rel,
          (idx["Pre_Stress_0_100"] ? r[idx["Pre_Stress_0_100"]] : nil),
          (idx["Pre_Mood"] ? r[idx["Pre_Mood"]] : nil),
          (idx["Pre_Fear_0_100"] ? r[idx["Pre_Fear_0_100"]] : nil),
          (idx["Pre_Trust_Player"] ? r[idx["Pre_Trust_Player"]] : nil)
        )

        @npc_state[npc_id] = state
        @npc_rel_player[npc_id] = rel

        pre_stress = state["Stress_0_100"].to_i
        pre_fear = state["Fear_0_100"].to_i

        v = choose_variant(npc_id, intent_id, tags, flags)
        got_vid = (v ? (v["VariantID"] || "") : "")
        exp_vid = (idx["ExpectedVariantID"] ? (r[idx["ExpectedVariantID"]] || "") : "")
        exp_preview = (idx["ExpectedTextPreview"] ? (r[idx["ExpectedTextPreview"]] || "") : "")

        ok = true
        details = []

        if exp_vid != "" && got_vid != exp_vid
          ok = false
          details << "VariantID exp=#{exp_vid} got=#{got_vid}"
        end

        if v != nil
          if exp_preview != ""
            got_text = (v["Text"] || "")
            if got_text[0, exp_preview.length] != exp_preview
              ok = false
              details << "TextPreview mismatch"
            end
          end

          apply_deltas!(npc_id, v, flags)

          exp_d_stress = (idx["Expected_DeltaStress"] ? (r[idx["Expected_DeltaStress"]] || "") : "")
          exp_d_fear = (idx["Expected_DeltaFear"] ? (r[idx["Expected_DeltaFear"]] || "") : "")
          exp_set_mood = (idx["Expected_SetMood"] ? (r[idx["Expected_SetMood"]] || "") : "")
          exp_stress_after = (idx["Expected_Stress_After"] ? (r[idx["Expected_Stress_After"]] || "") : "")
          exp_fear_after = (idx["Expected_Fear_After"] ? (r[idx["Expected_Fear_After"]] || "") : "")
          exp_add_flags = (idx["Expected_AddFlags"] ? (r[idx["Expected_AddFlags"]] || "") : "")
          exp_clear_flags = (idx["Expected_ClearFlags"] ? (r[idx["Expected_ClearFlags"]] || "") : "")
          exp_add_events = (idx["Expected_AddRecentEvent"] ? (r[idx["Expected_AddRecentEvent"]] || "") : "")
          exp_clear_events = (idx["Expected_ClearRecentEvent"] ? (r[idx["Expected_ClearRecentEvent"]] || "") : "")


          got_stress = @npc_state[npc_id]["Stress_0_100"].to_i
          got_fear = @npc_state[npc_id]["Fear_0_100"].to_i
          got_mood = @npc_state[npc_id]["Mood"].to_s

          if exp_d_stress != "" && (got_stress - pre_stress) != exp_d_stress.to_i
            ok = false
            details << "DeltaStress exp=#{exp_d_stress} got=#{(got_stress - pre_stress)}"
          end
          if exp_d_fear != "" && (got_fear - pre_fear) != exp_d_fear.to_i
            ok = false
            details << "DeltaFear exp=#{exp_d_fear} got=#{(got_fear - pre_fear)}"
          end
          if exp_set_mood != "" && got_mood != exp_set_mood
            ok = false
            details << "SetMood exp=#{exp_set_mood} got=#{got_mood}"
          end
          if exp_stress_after != "" && got_stress != exp_stress_after.to_i
            ok = false
            details << "StressAfter exp=#{exp_stress_after} got=#{got_stress}"
          end
          if exp_fear_after != "" && got_fear != exp_fear_after.to_i
            ok = false
            details << "FearAfter exp=#{exp_fear_after} got=#{got_fear}"
          end
          if exp_add_flags != ""
            _parse_list(exp_add_flags).each do |f|
              if flags[f] != true
                ok = false
                details << "AddFlags missing #{f}"
              end
            end
          end

          if exp_clear_flags != ""
            _parse_list(exp_clear_flags).each do |f|
              if flags[f] == true
                ok = false
                details << "ClearFlags expected cleared #{f}"
              end
            end

          # Expected recent event operations (persistent store)
          if (exp_add_events != "" || exp_clear_events != "") && defined?(RM_RecentEvents)
            begin
              if exp_add_events != ""
                _parse_list(exp_add_events).each do |e|
                  if RM_RecentEvents.has?(e, npc_id) != true
                    ok = false
                    details << "AddRecentEvent expected present #{e}"
                  end
                end
              end
              if exp_clear_events != ""
                _parse_list(exp_clear_events).each do |e|
                  if RM_RecentEvents.has?(e, npc_id) == true
                    ok = false
                    details << "ClearRecentEvent expected cleared #{e}"
                  end
                end
              end
            rescue
              # ignore
            end
          end
          end
        else
          ok = false if exp_vid != ""
          details << "NoVariant" if got_vid == ""
        end

        if ok
          pass += 1
        else
          fail += 1
        end

        results << {
          "TestID" => tid,
          "NPCID" => npc_id,
          "IntentID" => intent_id,
          "SelectedVariantID" => got_vid,
          "PASS" => ok ? "TRUE" : "FALSE",
          "Details" => details.join("; ")
        }
      end

      if show_message && defined?($game_message)
        $game_message.add("[DIALOGUE TESTS] pass=#{pass} fail=#{fail}")
      end
      results
    end

    def self.run_scenarios_dialogue(show_message = true)
      ensure_loaded!
      h, rows = CSVLite.read_table("QA/TEST_SCENARIOS_DIALOGUE.csv")
      return [] if h == nil || rows == nil

      idx = {}
      h.each_with_index { |name, i| idx[name] = i }

      results = []
      pass = 0
      fail = 0

      rows.each do |r|
        sid = (idx["ScenarioID"] ? (r[idx["ScenarioID"]] || "") : "")
        npc_id = (idx["NPCID"] ? (r[idx["NPCID"]] || "") : "")

        state = (@npc_state[npc_id] || {"Stress_0_100"=>"0","Fear_0_100"=>"0","Mood"=>"NEUTRAL","OutburstCooldown"=>"0"}).dup
        rel = (@npc_rel_player[npc_id] || {"Trust_Player"=>"50","Respect_Player"=>"50","Debt_Player"=>"0"}).dup

        setup = (idx["SetupState"] ? (r[idx["SetupState"]] || "") : "")
        if setup != ""
          setup.split(";").each do |p|
            kv = p.strip.split("=")
            next if kv.length < 2
            k = kv[0].strip
            v = kv[1].strip
            if k.index("Trust_") == 0 || k.index("Respect_") == 0 || k.index("Debt_") == 0
              rel[k] = v
            else
              # Aliases for human-friendly scenario/test inputs
              if k == "Stress"
                state["Stress_0_100"] = v
              elsif k == "Fear"
                state["Fear_0_100"] = v
              end
              state[k] = v
            end
          end
        end

        flags = {}
        _parse_list(idx["SetupFlagsTrue"] ? r[idx["SetupFlagsTrue"]] : "").each { |f| flags[f] = true }

        @npc_state[npc_id] = state
        @npc_rel_player[npc_id] = rel

        steps = (idx["Steps"] ? (r[idx["Steps"]] || "") : "")
        ok = true
        details = []

        if steps != ""
          steps.split("||").each_with_index do |step, si|
            kvs = {}
            extra_tags = []
            step.split(";").each do |pair|
              a = pair.strip
              next if a == ""
              k, v = a.split("=", 2)
              if v == nil
                extra_tags << k.strip
              else
                kvs[k.strip] = v.strip
              end
            end


            intent_id = (kvs["Intent"] || kvs["IntentID"] || "").to_s
            tags = _parse_list(kvs["Tags"] || "")
            extra_tags.each { |t| tags << t if t != nil && t != "" }
            exp_vid = (kvs["ExpectVariant"] || kvs["ExpectedVariantID"] || "").to_s

            exp_mood = (kvs["ExpectMood"] || "").to_s
            exp_ds = (kvs["ExpectDeltaStress"] || "").to_s
            exp_df = (kvs["ExpectDeltaFear"] || "").to_s
            exp_add_flags = (kvs["AddFlags"] || "").to_s
            exp_clear_flags = (kvs["ClearFlags"] || "").to_s

            st_before = (@npc_state[npc_id] || {})
            stress_before = (st_before["Stress_0_100"] || "0").to_i
            fear_before = (st_before["Fear_0_100"] || "0").to_i

            v = choose_variant(npc_id, intent_id, tags, flags)
            got_vid = (v ? (v["VariantID"] || "") : "")

            if exp_vid != "" && got_vid != exp_vid
              ok = false
              details << "Step#{si+1} VariantID exp=#{exp_vid} got=#{got_vid}"
            end

            apply_deltas!(npc_id, v, flags) if v != nil

            st_after = (@npc_state[npc_id] || st_before)
            stress_after = (st_after["Stress_0_100"] || stress_before.to_s).to_i
            fear_after = (st_after["Fear_0_100"] || fear_before.to_s).to_i
            mood_after = (st_after["Mood"] || "").to_s

            if exp_ds != ""
              got = stress_after - stress_before
              exp = exp_ds.to_i
              if got != exp
                ok = false
                details << "Step#{si+1} DeltaStress exp=#{exp} got=#{got}"
              end
            end

            if exp_df != ""
              got = fear_after - fear_before
              exp = exp_df.to_i
              if got != exp
                ok = false
                details << "Step#{si+1} DeltaFear exp=#{exp} got=#{got}"
              end
            end

            if exp_mood != "" && mood_after != exp_mood
              ok = false
              details << "Step#{si+1} Mood exp=#{exp_mood} got=#{mood_after}"
            end

            if exp_add_flags != ""
              _parse_list(exp_add_flags).each do |f|
                if flags[f] != true
                  ok = false
                  details << "Step#{si+1} AddFlags expected set #{f}"
                end
              end
            end

            if exp_clear_flags != ""
              _parse_list(exp_clear_flags).each do |f|
                if flags[f] == true
                  ok = false
                  details << "Step#{si+1} ClearFlags expected cleared #{f}"
                end
              end
            end
          end
        end

        if ok
          pass += 1
        else
          fail += 1
        end

        results << {
          "ScenarioID" => sid,
          "NPCID" => npc_id,
          "PASS" => ok ? "TRUE" : "FALSE",
          "Details" => details.join("; ")
        }
      end

      if show_message && defined?($game_message)
        $game_message.add("[DIALOGUE SCENARIOS] pass=#{pass} fail=#{fail}")
      end
      results
    end

  end
end
