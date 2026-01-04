# RM_UI_SKILL_EQUIP_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: UI mínima para equipar skills em slots (debug/local-test).
# compatible: RGSS1

module RM_UI
  def self.open_skills
    $scene = RM_Scene_SkillEquip.new
  rescue
  end
end

class RM_Scene_SkillEquip
  SLOTS = 4
  def main
    @help = Window_Help.new
    @help.set_text("Skills equipadas (debug). Enter para equipar no slot atual. ←/→ troca slot. Esc sai.")
    @slot = 0
    @list = Window_Command.new(320, RM_SkillData.skill_names)
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
    @status.contents.clear
    @status.draw_text(0,0,280,32,"Slot: #{@slot+1}/#{SLOTS}")
    eq = ($game_system && $game_system.rm_skills_equipped) ? $game_system.rm_skills_equipped : {}
    RM_SkillData.sanitize_equipped!(eq)
    4.times do |i|
      v = eq[i] || '(vazio)'
      @status.draw_text(0, 32 + i*32, 280, 32, "S#{i+1}: #{v}")
    end
  rescue
  end

  def update
    @list.update
    if Input.trigger?(Input::B)
      $scene = Scene_Map.new
      return
    end
    if Input.trigger?(Input::LEFT)
      @slot = (@slot - 1) % SLOTS
      refresh_status
    elsif Input.trigger?(Input::RIGHT)
      @slot = (@slot + 1) % SLOTS
      refresh_status
    elsif Input.trigger?(Input::C)
      idx = @list.index
      sid = RM_SkillData.skill_ids[idx]
      if $game_system
        $game_system.rm_skills_equipped[@slot] = sid
      end
      refresh_status
    end
  end
end

module RM_SkillData
  def self._load
    rows = RM_Data.csv_rows('Data/RM_CSV/ACT1_COMBAT_SKILLS_CANON.csv')
    allowed_class = $game_system && $game_system.respond_to?(:rm_class_key) ? $game_system.rm_class_key : nil
    ids=[]
    names=[]
    rows.each do |r|
      sid = r['SkillID'] || r['ID']
      next if sid.nil? || sid==''
      class_key = r['ClassKey'] || r['Classe']
      next if allowed_class && class_key && class_key != allowed_class
      ids << sid
      label = r['DisplayName'] || sid
      label = "#{label} (#{class_key})" if class_key && class_key != '' && allowed_class.nil?
      names << label
    end
    if ids.empty?
      ids = ['SKILL_NONE']
      names = ['(sem skills compatíveis no Data/RM_CSV)']
    end
    [ids,names]
  rescue
    [['SKILL_NONE'], ['(sem skills)']]
  end

  def self.skill_ids; @cache ||= _load; @cache[0]; end
  def self.skill_names; @cache ||= _load; @cache[1]; end

  def self.allowed_ids
    @cache ||= _load
    @cache[0]
  end

  def self.sanitize_equipped!(eq_hash)
    allowed = allowed_ids
    4.times do |i|
      sid = eq_hash[i]
      next if sid.nil?
      eq_hash[i] = nil unless allowed.include?(sid)
    end
  end
end
