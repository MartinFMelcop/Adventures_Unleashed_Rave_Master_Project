# RM_UI_QUEST_JOURNAL_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: UI de journal de quests com objetivo, progresso e recompensas.
# compatible: RGSS1

module RM_UI
  def self.open_journal
    $scene = RM_Scene_QuestJournal.new
  rescue
  end
end

module RM_QuestState
  STATUS_PENDING = 'PENDENTE'
  STATUS_ACTIVE = 'ATIVA'
  STATUS_DONE = 'CONCLUIDA'

  def self._state
    return {} if $game_system.nil?
    $game_system.rm_quests_state ||= {}
  end

  def self.ensure(qid)
    st = _state
    st[qid] ||= {:status => STATUS_PENDING, :step_index => 1}
    st[qid]
  end

  def self.status(qid)
    ensure(qid)[:status]
  end

  def self.status_label(qid)
    case status(qid)
    when STATUS_DONE then 'Concluída'
    when STATUS_ACTIVE then 'Em andamento'
    else 'Pendente'
    end
  end

  def self.step_index(qid)
    ensure(qid)[:step_index]
  end

  def self.start!(qid)
    ensure(qid)[:status] = STATUS_ACTIVE
    ensure(qid)[:step_index] = 1 if ensure(qid)[:step_index].nil?
  end

  def self.complete!(qid)
    ensure(qid)[:status] = STATUS_DONE
  end
end

class RM_Scene_QuestJournal
  def main
    @help = Window_Help.new
    @help.set_text("Quest Journal: Enter=ativar/avançar, Shift=concluir, Esc=sair.")
    @list = Window_Command.new(320, RM_QuestData.quest_names_with_status)
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
    quest = RM_QuestData.quest_view(qid)
    status = RM_QuestState.status_label(qid)
    @details.draw_text(0,0,300,32,"#{qid} (#{status})")
    y = 32
    @details.draw_text(0,y,300,32,"#{quest[:title]}")
    y += 32
    @details.draw_text(0,y,300,32,"Objetivo:")
    y += 32
    @details.draw_text(0,y,300,64,quest[:objective][0,140])
    y += 64
    step = quest[:step]
    @details.draw_text(0,y,300,32,"Passo atual:")
    y += 32
    @details.draw_text(0,y,300,64,(step || 'Sem passos mapeados')[0,140])
    y += 64
    reward = quest[:reward]
    @details.draw_text(0,y,300,32,"Recompensas:")
    y += 32
    @details.draw_text(0,y,300,64,(reward == '' ? '(não definido)' : reward)[0,140])
    y += 64
    @details.draw_text(0,y,300,32,"Mapa/Refs: #{quest[:map_key]}")
    y += 32
    @details.draw_text(0,y,300,32,"Tipo: #{quest[:ref_type]} | Canon: #{quest[:canon]}")
  rescue
  end

  def update
    @list.update
    if Input.trigger?(Input::B)
      $scene = Scene_Map.new
      return
    end
    if Input.trigger?(Input::C)
      qid = RM_QuestData.quest_ids[@list.index]
      RM_QuestState.start!(qid)
      @list.commands = RM_QuestData.quest_names_with_status
      refresh_details
    elsif Input.trigger?(Input::A)
      qid = RM_QuestData.quest_ids[@list.index]
      RM_QuestState.complete!(qid)
      @list.commands = RM_QuestData.quest_names_with_status
      refresh_details
    elsif Input.trigger?(Input::UP) || Input.trigger?(Input::DOWN)
      refresh_details
    end
  end
end

module RM_QuestData
  CSV_QUESTS = 'Data/RM_CSV/QUESTS_EM_CONSTRUCAO.csv'
  CSV_SIDEQUESTS = 'Data/RM_CSV/SIDEQUESTS_EM_CONSTRUCAO.csv'
  CSV_STEPS = 'Data/RM_CSV/QUEST_STEPS.csv'
  CSV_JOURNAL_VIEW = 'Data/RM_CSV/QUEST_JOURNAL_VIEW.csv'

  def self._rows
    @rows ||= begin
      quest_rows('QUEST', CSV_QUESTS) + quest_rows('SIDEQUEST', CSV_SIDEQUESTS)
    end
  end

  def self.quest_rows(ref_type, path)
    RM_Data.csv_rows(path).map do |r|
      id = r['IdQuest'] || r['QuestID'] || r['ID']
      next if id.nil? || id == ''
      {
        :id => id,
        :ref_type => ref_type,
        :title => pick(r, ['Descrição Resumida','Descricao Resumida','Descrição Completa','Descricao Completa','Texto_UI','Title','Nome']) || '(sem título)',
        :objective => pick(r, ['Texto_UI','Critério de Aceite','Descricao Completa','Descrição Completa','Descricao Resumida','Descrição Resumida']) || '',
        :reward => pick(r, ['Recompensas','Recompensas_Validacao']) || '',
        :map_key => pick(r, ['ChaveMapa','Localização','Localizacao']) || '',
        :canon => (r['Canon'] || r['CanonStatus'] || '').strip
      }
    end.compact
  end

  def self.pick(row, keys)
    keys.each do |k|
      v = row[k]
      return v.strip if v && v.strip != ''
    end
    nil
  end

  def self.quest_ids
    ids = []
    _rows.each do |r|
      ids << r[:id]
    end
    ids = ['(sem quests)'] if ids.empty?
    ids
  end

  def self.quest_names_with_status
    names=[]
    _rows.each do |r|
      names << "#{r[:id]} - #{r[:title]} [#{RM_QuestState.status_label(r[:id])}]"
    end
    names = ['(sem quests no Data/RM_CSV)'] if names.empty?
    names
  end

  def self._journal_index
    return @journal_index unless @journal_index.nil?
    @journal_index = {}
    RM_Data.csv_rows(CSV_JOURNAL_VIEW).each do |r|
      ref_id = r['RefID'] || r['IdQuest'] || r['QuestID']
      next if ref_id.nil? || ref_id == ''
      @journal_index[ref_id] = r
    end
    @journal_index
  rescue
    @journal_index = {}
  end

  def self._steps_index
    return @steps_index unless @steps_index.nil?
    @steps_index = {}
    RM_Data.csv_rows(CSV_STEPS).each do |r|
      ref = r['RefID']
      next if ref.nil? || ref == ''
      (@steps_index[ref] ||= []) << r
    end
    @steps_index
  rescue
    @steps_index = {}
  end

  def self.quest_view(qid)
    quest = _rows.find { |r| r[:id] == qid } || {:id=>qid, :ref_type=>'QUEST', :title=>'(desconhecida)', :objective=>'', :reward=>'', :map_key=>'', :canon=>''}
    journal = _journal_index[qid]
    objective = journal.nil? ? quest[:objective] : (journal['Objetivo'] || quest[:objective] || '')
    step = current_step(qid)
    {
      :id => quest[:id],
      :ref_type => quest[:ref_type],
      :title => quest[:title],
      :objective => objective,
      :reward => quest[:reward],
      :map_key => quest[:map_key],
      :canon => (quest[:canon] == '' ? (journal ? journal['CanonStatus'] : '') : quest[:canon]),
      :step => step
    }
  end

  def self.current_step(qid)
    idx = RM_QuestState.step_index(qid)
    steps = _steps_index[qid] || []
    found = steps.find { |s| s['StepIndex'].to_i == idx }
    return found['StepText'] if found
    steps.first && steps.first['StepText']
  end
end
