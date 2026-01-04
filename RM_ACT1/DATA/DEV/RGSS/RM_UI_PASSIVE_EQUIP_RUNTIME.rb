# RM_UI_PASSIVE_EQUIP_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: UI mínima para escolher 1 passiva equipada (debug/local-test).
# compatible: RGSS1

module RM_UI
  def self.open_passive
    $scene = RM_Scene_PassiveEquip.new
  rescue
  end
end

class RM_Scene_PassiveEquip
  def main
    @help = Window_Help.new
    @help.set_text("Passiva equipada (debug). Enter para equipar. Esc para sair.")
    @list = Window_Command.new(320, RM_PassiveData.passive_names)
    @list.x = 0
    @list.y = 64
    @status = Window_Base.new(320, 64, 320, 416)
    refresh_status
    Graphics.transition
    loop do
      Graphics.update
      Input.update
      update
      break if $scene != self
    end
    Graphics.freeze
    @help.dispose
    @list.dispose
    @status.dispose
  end

  def refresh_status
    cur = ($game_system && $game_system.rm_passive_equipped_id) ? $game_system.rm_passive_equipped_id : nil
    @status.contents.clear
    @status.draw_text(0,0,280,32,"Equipada: #{cur ? cur.to_s : 'nenhuma'}")
    info = RM_PassiveData.info(cur)
    if info
      @status.draw_text(0,32,300,32,"Classe: #{info[:class_key]} (#{info[:variant]})")
      @status.draw_text(0,64,300,32,"Tier/Raridade: #{info[:tier]} / #{info[:rarity]}")
      @status.draw_text(0,96,300,32,"Regra: #{info[:equip_rule]}")
      @status.draw_text(0,128,300,32,"Desc: #{info[:desc]}")
    else
      @status.draw_text(0,32,300,32,"Sem passiva carregada")
    end
  rescue
  end

  def update
    @list.update
    if Input.trigger?(Input::B)
      $scene = Scene_Map.new
      return
    end
    if Input.trigger?(Input::C)
      idx = @list.index
      pid = RM_PassiveData.passive_ids[idx]
      if $game_system
        rule = RM_PassiveData.equip_rule_for(pid)
        @help.set_text("Equipando #{pid} (#{rule || 'UNSPECIFIED'})")
        $game_system.rm_passive_equipped_id = pid
      end
      refresh_status
    end
  end
end

module RM_PassiveData
  CSV_PASSIVES = 'Data/RM_CSV/ACT1_PASSIVES_CANON.csv'
  CSV_EQUIP_RULES = 'Data/RM_CSV/PASSIVE_EQUIP_RULES.csv'

  def self._load
    rows = RM_Data.csv_rows(CSV_PASSIVES)
    ids=[]
    names=[]
    info={}
    rows.each do |r|
      pid = r['PassiveID'] || r['ID']
      next if pid.nil? || pid==''
      ids << pid
      names << (r['DisplayName'] || r['Nome'] || pid)
      info[pid] = {
        :class_key => r['ClassKey'] || 'UNKNOWN',
        :variant => r['ClassVariant'] || '-',
        :tier => r['TierPassive'] || r['Tier'] || '?',
        :rarity => r['Rarity'] || 'COMMON',
        :equip_rule => r['EquipRuleID'] || '-',
        :desc => r['Descricao'] || r['Description'] || ''
      }
    end
    if ids.empty?
      ids = ['PASSIVE_NONE']
      names = ['(sem passivas no Data/RM_CSV)']
    end
    rules = {}
    RM_Data.csv_rows(CSV_EQUIP_RULES).each do |r|
      rid = r['EquipRuleID'] || r['ID']
      next if rid.nil? || rid==''
      rules[rid] = r
    end
    @cache = [ids,names,info,rules]
  rescue
    @cache = [['PASSIVE_NONE'], ['(sem passivas)'], {}, {}]
  end

  def self.passive_ids
    @cache ||= _load
    @cache[0]
  end
  def self.passive_names
    @cache ||= _load
    @cache[1]
  end
  def self.info(pid)
    @cache ||= _load
    @cache[2][pid]
  end
  def self.equip_rule_for(pid)
    @cache ||= _load
    info = @cache[2][pid]
    rules = @cache[3]
    return nil if info.nil?
    rid = info[:equip_rule]
    rule = rules[rid]
    return rid if rule.nil?
    slot = rule['SlotGroup'] || 'PASSIVE_MAIN'
    max = rule['MaxEquipped'] || '1'
    "#{rid} (#{slot}, max #{max})"
  end
end
