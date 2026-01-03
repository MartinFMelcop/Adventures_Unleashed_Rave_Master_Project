# RM_UI_QUEST_JOURNAL_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: UI mínima de journal de quests (debug/local-test).
# compatible: RGSS1

module RM_UI
  def self.open_journal
    $scene = RM_Scene_QuestJournal.new
  rescue
  end
end

class RM_Scene_QuestJournal
  def main
    @help = Window_Help.new
    @help.set_text("Quest Journal (debug). Esc para sair.")
    @list = Window_Command.new(320, RM_QuestData.quest_names)
    @list.x = 0
    @list.y = 64
    @details = Window_Base.new(320, 64, 320, 416)
    refresh_details
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
    @details.dispose
  end

  def refresh_details
    @details.contents.clear
    idx = @list.index
    qid = RM_QuestData.quest_ids[idx]
    text = RM_QuestData.quest_desc(qid)
    @details.draw_text(0,0,280,32,qid.to_s)
    @details.draw_text(0,32,280,96,text[0,120])
  rescue
  end

  def update
    @list.update
    if Input.trigger?(Input::B)
      $scene = Scene_Map.new
      return
    end
    if Input.trigger?(Input::C) || Input.trigger?(Input::UP) || Input.trigger?(Input::DOWN)
      refresh_details
    end
  end
end

module RM_QuestData
  def self._rows
    @rows ||= RM_Data.csv_rows('Data/RM_CSV/QUESTS_EM_CONSTRUCAO.csv')
  end
  def self.quest_ids
    ids = []
    _rows.each do |r|
      qid = r['QuestID'] || r['ID']
      next if qid.nil? || qid==''
      ids << qid
    end
    ids = ['(sem quests)'] if ids.empty?
    ids
  end
  def self.quest_names
    names=[]
    _rows.each do |r|
      qid = r['QuestID'] || r['ID']
      next if qid.nil? || qid==''
      names << "#{qid} - #{(r['Title'] || r['Nome'] || '').strip}"
    end
    names = ['(sem quests no Data/RM_CSV)'] if names.empty?
    names
  end
  def self.quest_desc(qid)
    _rows.each do |r|
      id = r['QuestID'] || r['ID']
      next unless id == qid
      return (r['Summary'] || r['Descrição'] || r['Descricao'] || '')
    end
    ''
  end
end
