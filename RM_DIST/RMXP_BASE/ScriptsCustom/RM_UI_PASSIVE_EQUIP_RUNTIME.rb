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
        $game_system.rm_passive_equipped_id = pid
      end
      refresh_status
    end
  end
end

module RM_PassiveData
  def self._load
    rows = RM_Data.csv_rows('Data/RM_CSV/ACT1_PASSIVES_CANON.csv')
    ids=[]
    names=[]
    rows.each do |r|
      pid = r['PassiveID'] || r['ID']
      next if pid.nil? || pid==''
      ids << pid
      names << (r['DisplayName'] || pid)
    end
    if ids.empty?
      ids = ['PASSIVE_NONE']
      names = ['(sem passivas no Data/RM_CSV)']
    end
    [ids,names]
  rescue
    [['PASSIVE_NONE'], ['(sem passivas)']]
  end

  def self.passive_ids
    @cache ||= _load
    @cache[0]
  end
  def self.passive_names
    @cache ||= _load
    @cache[1]
  end
end
