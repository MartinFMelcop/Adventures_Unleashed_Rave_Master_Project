# RM_REPUTATION_RUNTIME.rb (RGSS1 / Ruby 1.8)
# Canon: AJ_000275 — Reputação por região (sem reputação 0).
# Fonte de dados: Data/RM_CSV/DIC_REPUTACAO_*.csv, REP_REGRAS.csv, REPUTATION_RULES.csv
# Seed ACT1 (Vila Rose): Data/RM_CSV/REP_SEED_ANTECEDENTE_ACT1.csv

module RM_Reputation
  ZONES = ["VILA_ROSE","FADAS","GOBLINS","BREJO","REINO_ELFO"]

  def self._store
    $game_system.rm_reputation ||= {}
    $game_system.rm_reputation
  end

  def self.get(zone)
    z = zone.to_s.upcase
    v = _store[z]
    return v.nil? ? nil : v.to_i
  end

  def self.set(zone, value)
    z = zone.to_s.upcase
    v = value.to_i
    v = normalize_no_zero(v, 0)
    v = clamp(v)
    _store[z] = v
    v
  end

  def self.add(zone, delta)
    z = zone.to_s.upcase
    cur = get(z)
    cur = default_for(z) if cur.nil?
    d = delta.to_i
    # saturation: IGNORE when already at clamp min/max
    if cur == clamp_min && d < 0
      return cur
    end
    if cur == clamp_max && d > 0
      return cur
    end

    tentative = cur + d

    # crossing rule: to cross sign, need |delta| >= threshold_abs
    if (cur < 0 && tentative > 0) || (cur > 0 && tentative < 0)
      if d.abs < crossing_threshold_abs
        return cur
      end
    end

    # no zero: if results 0, only allow if |delta| >= threshold_abs (meaning a real flip)
    if tentative == 0
      if d.abs >= crossing_threshold_abs
        tentative = (d > 0) ? 1 : -1
      else
        return cur
      end
    end

    tentative = clamp(tentative)
    _store[z] = tentative
    tentative
  end

  def self.seed_vila_rose_from_antecedente(antecedente_key)
    key = antecedente_key.to_s.upcase
    seed = seed_lookup_vila_rose(key)
    set("VILA_ROSE", seed)
  end

  def self.seed_initial(antecedente_key=nil)
    # set defaults for all zones if missing
    ZONES.each do |z|
      _store[z] = default_for(z) if get(z).nil?
    end
    if !antecedente_key.nil?
      seed_vila_rose_from_antecedente(antecedente_key)
    end
  end

  def self.effects_for(zone)
    # Lightweight: runtime uses REPUTATION_RULES.csv exported; parsing/caching can be added later.
    # For now, provide hook. Return empty array by default.
    []
  end

  # ---- config (defaults) ----
  def self.clamp_min; -3; end
  def self.clamp_max;  3; end
  def self.crossing_threshold_abs; 2; end

  def self.clamp(v)
    return clamp_min if v < clamp_min
    return clamp_max if v > clamp_max
    v
  end

  def self.normalize_no_zero(v, sign_hint)
    return v if v != 0
    return (sign_hint >= 0) ? 1 : -1
  end

  def self.default_for(zone)
    # defaults (canon in DIC_REPUTACAO_REGIOES.csv); duplicated here for now.
    z = zone.to_s.upcase
    return -3 if z == "FADAS"
    return -3 if z == "GOBLINS"
    return -1 if z == "BREJO"
    return -1 if z == "REINO_ELFO"
    # VILA_ROSE is seeded via antecedente; fallback:
    1
  end

  def self.seed_lookup_vila_rose(key)
    # Minimal lookup (canon table exported); keep consistent with ACT1_REP_SEED_ANTECEDENTE_CANON.
    return -1 if key == "CULTISTA"
    return -1 if key == "CRIMINOSO"
    return -1 if key == "SOBREVIVENTE"
    1
  end
end
