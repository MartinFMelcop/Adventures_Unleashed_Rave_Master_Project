# RM_COMBAT_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: Combat formulas runtime helpers (hit/crit/damage/mitigation/status apply/duration) aligned to data-model.
# audience: ai_only / developer
# notes:
# - RGSS (Ruby 1.8): avoid modern Ruby features; keep allocations small.
# - Data source: Data/RM_CSV/COMBAT_FORMULAS.csv (optional). Fallback defaults are embedded.
# - This module is a helper/API; full integration into RMXP battle loop can be done in follow-up AJ(s).

module RM_Combat
  CSV_DIR = "Data/RM_CSV/"
  CSV_FORMULAS = CSV_DIR + "COMBAT_FORMULAS.csv"

  # ----------------
  # Defaults (Opção C)
  # ----------------
  DEFAULTS = {
    :base_hit => 0.90,
    :hit_min  => 0.05,
    :hit_max  => 0.95,
    :lvl_coef => 0.02,
    :lvl_min  => 0.85,
    :lvl_max  => 1.15,

    :crit_cap => 0.50,
    :crit_mult => 1.50,
    :crit_base => 1.00,

    :k_base => 100.0,
    :k_lvl  => 10.0,

    :apply_min => 0.05,
    :apply_max => 0.95
  }

  def self.clamp(x, lo, hi)
    return lo if x < lo
    return hi if x > hi
    return x
  end

  def self.safe_ratio(n, d)
    dd = d
    dd = 0.000001 if dd <= 0.0
    return n / dd
  end

  # ----------------
  # Formula helpers
  # ----------------

  # Hit chance (ACC vs EVA)
  # BaseHit_skill is per-skill; if nil uses DEFAULTS[:base_hit].
  def self.hit_chance(acc, eva, lvl_atk, lvl_def, base_hit_skill)
    base_hit = base_hit_skill.nil? ? DEFAULTS[:base_hit] : base_hit_skill.to_f
    accv = acc.to_f
    evav = eva.to_f
    ratio = safe_ratio(accv, (accv + evav))
    lvl_factor = 1.0 + DEFAULTS[:lvl_coef] * (lvl_atk.to_i - lvl_def.to_i)
    lvl_factor = clamp(lvl_factor, DEFAULTS[:lvl_min], DEFAULTS[:lvl_max])
    p = base_hit * ratio * lvl_factor
    return clamp(p, DEFAULTS[:hit_min], DEFAULTS[:hit_max])
  end

  # Crit chance uses CRIT as percent points (e.g., 10 => 10%).
  def self.crit_chance(crit_percent, crit_base_skill)
    base = crit_base_skill.nil? ? DEFAULTS[:crit_base] : crit_base_skill.to_f
    p = base * (crit_percent.to_f / 100.0)
    return clamp(p, 0.0, DEFAULTS[:crit_cap])
  end

  # Raw damage per-skill (ATK/MATK rating, EscalaCoef, Letalidade).
  def self.raw_damage(atk_or_matk, escala_coef, letalidade)
    a = atk_or_matk.to_f
    s = escala_coef.to_f
    l = letalidade.to_f
    return (a * s) * (1.0 + l)
  end

  # Mitigation with K = 100 + 10*Lvl_def.
  def self.mitigate(raw, def_or_mdef, lvl_def)
    k = DEFAULTS[:k_base] + DEFAULTS[:k_lvl] * lvl_def.to_i
    d = def_or_mdef.to_f
    mit = safe_ratio(k, (k + d))
    return (raw.to_f * mit).round
  end

  # Debuff apply chance (Gate 2): BaseApply * EFF/(EFF+RES) with clamp.
  # EFF/RES are non-negative "weights" (percent points can be used as-is).
  def self.apply_chance(eff, res, base_apply_skill)
    base = base_apply_skill.nil? ? 1.0 : base_apply_skill.to_f
    e = eff.to_f
    r = res.to_f
    ratio = safe_ratio(e, (e + r))
    p = base * ratio
    return clamp(p, DEFAULTS[:apply_min], DEFAULTS[:apply_max])
  end

  # Duration final: BaseDur per-skill; duration modifiers as percent points.
  # Debuff: DurApply = DEBUFF_DUR_APPLY, Ten = DEBUFF_TEN
  # Buff:   DurApply = BUFF_DUR + BUFF_REC, Ten = 0
  def self.final_duration(base_dur, dur_apply_percent, ten_percent)
    base = base_dur.to_f
    mult = 1.0 + (dur_apply_percent.to_f / 100.0) - (ten_percent.to_f / 100.0)
    dur = (base * mult).round
    dur = 1 if dur < 1
    return dur
  end

  # DOT ticks from design (HPmax percent). These are defaults; can be moved to data later.
  # Poison: 6% HPmax
  # Bleed: 3% HPmax (+ anti-heal handled as separate modifier)
  # Burn:  3% HPmax (+ ATK down handled as separate modifier)
  def self.dot_tick(status_id, hp_max)
    hp = hp_max.to_i
    sid = status_id.to_s.upcase
    if sid == "POISON"
      return (hp * 0.06).round
    elsif sid == "BLEED"
      return (hp * 0.03).round
    elsif sid == "BURN"
      return (hp * 0.03).round
    end
    return 0
  end

  # Reapply policy: if status already present, add duration to remaining time.
  # The actual status container is defined by the caller (battle engine/state).
  def self.reapply_duration(remaining, add)
    r = remaining.to_i + add.to_i
    r = 1 if r < 1
    return r
  end
end
