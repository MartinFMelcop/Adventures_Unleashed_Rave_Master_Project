# RM_CHARACTER_CREATE_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: UI de criação inicial (Classe + Antecedente) antes do início do jogo
# compatible: RGSS1 (Ruby 1.8 / RPG Maker XP)
# data_source:
# - Data/RM_CSV/ACT1_*_CANON.csv (canon) → mapeamento Classe×Antecedente permitido + IDs
# notes:
# - NÃO aplica efeitos mecânicos (loadout/equip/dinheiro) aqui; apenas persiste a escolha no save.
# - Safe defaults: se restrição não existir, mostra todos os antecedentes.

module RM_CharCreate
  CLASSES = ["KNIGHT", "WARRIOR", "BERSERKER", "ROGUE", "RANGER", "PYROMANCER", "CRYOMANCER", "DRUID", "CLERIC", "SHAMAN"]

  ANTECEDENTES = [
    {:id=>1, :name=>"Erudito", :effect=>"Modifica apenas equipamentos/consumíveis/dinheiro"},
    {:id=>2, :name=>"Cultista", :effect=>"Modifica apenas equipamentos/consumíveis/dinheiro"},
    {:id=>3, :name=>"Acólito", :effect=>"Modifica apenas equipamentos/consumíveis/dinheiro"},
    {:id=>4, :name=>"Soldado", :effect=>"Modifica apenas equipamentos/consumíveis/dinheiro"},
    {:id=>5, :name=>"Guardião", :effect=>"Modifica apenas equipamentos/consumíveis/dinheiro"},
    {:id=>7, :name=>"Batedor", :effect=>"Modifica apenas equipamentos/consumíveis/dinheiro"},
    {:id=>8, :name=>"Criminoso", :effect=>"Modifica apenas equipamentos/consumíveis/dinheiro"},
    {:id=>9, :name=>"Artífice/Comerciante", :effect=>"Modifica apenas equipamentos/consumíveis/dinheiro"},
    {:id=>10, :name=>"Artista", :effect=>"Modifica apenas equipamentos/consumíveis/dinheiro"},
    {:id=>11, :name=>"Caçador", :effect=>"Modifica apenas equipamentos/consumíveis/dinheiro"},
    {:id=>12, :name=>"Sobrevivente", :effect=>"Modifica apenas equipamentos/consumíveis/dinheiro"}
  ]


  # --- Canon data override (Data/RM_CSV) ---
  def self._safe_read_csv(rel_path)
    return nil unless File.exist?(rel_path)
    raw = File.read(rel_path)
    lines = raw.split(/\r?\n/)
/)
    return nil if lines.empty?
    header = lines.shift.split(',', -1).map { |h| h.strip }
    rows = []
    lines.each do |ln|
      next if ln.nil? || ln.strip == ''
      cols = ln.split(',', -1)
      h = {}
      header.each_with_index do |k, i|
        h[k] = (cols[i] || '').strip
      end
      rows << h
    end
    rows
  rescue
    nil
  end

  # --- Loadout (kits iniciais) ---
  def self.load_kits
    return @kits_cache if @kits_cache
    kits = _safe_read_csv('Data/RM_CSV/KITS_INICIAIS.csv')
    @kits_cache = kits || []
  end

  def self._parse_money_delta(text)
    return 0 if text.nil?
    money = 0
    # B (bronze) = 1; S (silver) = 100; G (gold) = 10_000; P (platinum) = 1_000_000
    unit = { 'B' => 1, 'S' => 100, 'G' => 10_000, 'P' => 1_000_000 }
    text.scan(/dinheiro\s*([+-]?)(\d+)\s*([BSGP])/i) do |sign, num, u|
      mult = unit[u.upcase] || 1
      delta = num.to_i * mult
      delta *= -1 if sign == '-'
      money += delta
    end
    money
  end

  def self._find_item_by_name(name)
    return nil if name.nil?
    target = name.strip.downcase
    candidates = []
    [$data_items, $data_weapons, $data_armors].each do |arr|
      next if arr.nil?
      arr.each do |obj|
        next if obj.nil? || obj.name.nil?
        candidates << obj if obj.name.downcase.include?(target)
      end
    end
    candidates.first
  end

  def self._apply_item_token(token)
    return nil if token.nil?
    qty = 1
    if token =~ /(x|\+|-)\s*(\d+)/i
      qty = $2.to_i
      qty *= -1 if token.include?('-')
    end
    name = token.split(/\(|x|\+/).first.to_s.strip
    item = _find_item_by_name(name)
    return nil if item.nil?
    $game_party.gain_item(item, qty)
    { :name => item.name, :qty => qty }
  end

  def self.apply_loadout(class_key, antecedente_id)
    kits = load_kits
    return [] if kits.nil? || kits.empty?
    log = []
    kits.each do |r|
      next unless r['Classe'] == class_key
      next unless r['Antecedente'].to_s.strip != ''
      next unless r['Antecedente'].to_s.downcase.include?(antecedente_id.to_s.downcase)
      mud = r['Mudanca'].to_s
      money = _parse_money_delta(mud)
      if money != 0
        $game_party.gain_gold(money)
        log << "Dinheiro ajustado em #{money} (B base)."
      end
      mud.split(';').each do |tok|
        info = _apply_item_token(tok)
        log << "Item #{info[:name]} (#{info[:qty]})" if info
      end
    end
    if log.empty?
      # fallback: dar um pequeno kit genérico para evitar testes sem suprimentos
      potion = _find_item_by_name('Poção') || _find_item_by_name('Potion')
      if potion
        $game_party.gain_item(potion, 2)
        log << "Fallback: #{potion.name} x2"
      end
      $game_party.gain_gold(200)
      log << 'Fallback: dinheiro +200 (B).'
    end
    $game_system.rm_last_loadout_log = log
    log
  end

  def self.load_canon_data!
    classes = _safe_read_csv('Data/RM_CSV/ACT1_CLASSES_CANON.csv')
    antecedentes = _safe_read_csv('Data/RM_CSV/ACT1_ANTECEDENTES_CANON.csv')
    rel = _safe_read_csv('Data/RM_CSV/ACT1_REL_CLASS_ANTECEDENTE_CANON.csv')
    return false if classes.nil? || antecedentes.nil?

    cls_keys = []
    cls_order = {}
    cls_name = {}
    classes.each do |r|
      k = r['ClassKey'] || r['class_key'] || r['Key'] || r['ID']
      next if k.nil? || k == ''
      cls_keys << k
      cls_name[k] = r['DisplayName'] || r['Name'] || k
      cls_order[k] = (r['UI_Order'] || r['Order'] || '999').to_i
    end
    cls_keys = cls_keys.uniq.sort_by { |k| cls_order[k] || 999 }

    ants = []
    antecedentes.each do |r|
      aid = r['AntecedenteID'] || r['AntecedenteId'] || r['ID'] || r['AntecedenteKey']
      next if aid.nil? || aid == ''
      name = r['DisplayName'] || r['Name'] || aid
      desc = r['ShortEffect'] || r['Effect'] || 'Modifica apenas equipamentos/consumíveis/dinheiro'
      num_str = aid.to_s.gsub(/[^0-9]/, '')
      num = (num_str == '' ? aid.to_i : num_str.to_i)
      ants << { :id => num, :name => name, :effect => desc }
    end

    allowed = {}
    if rel
    filtered = ANTECEDENTES.select { |a| ids.include?(a[:id]) }
    filtered.empty? ? ANTECEDENTES : filtered
    name = class_display_name(key)
    name.to_s.downcase.gsub('_',' ').split(' ').map{|w| w.capitalize}.join(' ')
    list = allowed_antecedentes_for(class_key)
    list = list.map{|a| a[:name]} if list.respond_to?(:first) && list.first.is_a?(Hash)
    if list.nil? || list.size == 0
      ante_name_list
    else
      list
    end
        num_str = aid.to_s.gsub(/[^0-9]/, '')
        num = (num_str == '' ? aid.to_i : num_str.to_i)
        allowed[ck] ||= []
        allowed[ck] << num
      end
    end

    CLASSES.replace(cls_keys)
    ANTECEDENTES.replace(ants)
    @allowed_by_class = allowed
    @class_display = cls_name
    true
  end

  def self.class_display_name(class_key)
    return class_key if @class_display.nil?
    @class_display[class_key] || class_key
  end

  def self.allowed_antecedentes_for(class_key)
    return ANTECEDENTES if @allowed_by_class.nil? || @allowed_by_class[class_key].nil?
    ids = @allowed_by_class[class_key]
    ANTECEDENTES.select { |a| ids.include?(a[:id]) }
  end

  load_canon_data!

  # Hash: class_key => [antecedente_name,...]
  ALLOWED = {
    "KNIGHT"=>["Soldado", "Guardião", "Acólito", "Erudito", "Sobrevivente"],
    "WARRIOR"=>["Soldado", "Guardião", "Caçador", "Criminoso", "Sobrevivente"],
    "BERSERKER"=>["Caçador", "Soldado", "Criminoso", "Cultista", "Sobrevivente"],
    "ROGUE"=>["Criminoso", "Batedor", "Artista", "Artífice/Comerciante", "Caçador", "Sobrevivente"],
    "RANGER"=>["Caçador", "Batedor", "Guardião", "Soldado", "Sobrevivente"],
    "PYROMANCER"=>["Erudito", "Cultista", "Acólito", "Soldado", "Sobrevivente"],
    "CRYOMANCER"=>["Soldado", "Guardião", "Erudito", "Acólito", "Sobrevivente"],
    "DRUID"=>["Caçador", "Batedor", "Acólito", "Erudito", "Sobrevivente"],
    "CLERIC"=>["Acólito", "Erudito", "Guardião", "Artífice/Comerciante", "Cultista", "Sobrevivente"],
    "SHAMAN"=>["Caçador", "Batedor", "Cultista", "Acólito", "Sobrevivente"]
  }

  def self.class_display(key)
    # "PYROMANCER" -> "Pyromancer"
    key.to_s.downcase.gsub('_',' ').split(' ').map{|w| w.capitalize}.join(' ')
  end

  def self.ante_by_name(name)
    ANTECEDENTES.find{|a| a[:name] == name}
  end

  def self.ante_name_list
    ANTECEDENTES.map{|a| a[:name]}
  end

  def self.allowed_for_class(class_key)
    list = ALLOWED[class_key]
    (list && list.size > 0) ? list : ante_name_list
  end
end

# Persistência no save
class Game_System
  attr_accessor :rm_class_key
  attr_accessor :rm_antecedente_id
  attr_accessor :rm_last_loadout_log
  attr_accessor :rm_prologue_seen
end

# Extensão segura do Window_Command para permitir atualizar comandos
class Window_Command
  def rm_set_commands(commands)
    @commands = commands
    @item_max = commands.size
    @column_max = 1 if @column_max.nil? || @column_max < 1
    refresh
    self.index = 0 if self.index.nil? || self.index >= @item_max
  end
end

class Window_RMDesc < Window_Base
  def initialize(x, y, w, h)
    super(x, y, w, h)
    @text = ""
    refresh
  end

  def set_text(text)
    text = "" if text.nil?
    return if text == @text
    @text = text
    refresh
  end

  def refresh
    self.contents.clear
    lines = @text.split("\n")
    y = 0
    lines.each do |line|
      self.contents.draw_text(4, y, self.width - 32, 32, line.to_s)
      y += 32
      break if y > self.height - 64
    end
  end
end

class Scene_CharacterCreate
  def main
    if $game_system && !$game_system.rm_prologue_seen
      RM_PrologueSlideshow.play_once
      $game_system.rm_prologue_seen = true
    end

    @help_window = Window_Help.new
    @help_window.set_text("Criação: escolha Classe e Antecedente (Enter/Z confirma; Esc/X volta)")

    # Layout base
    top_y = @help_window.height
    list_h = 320

    @class_keys = RM_CharCreate::CLASSES
    @class_names = @class_keys.map{|k| RM_CharCreate.class_display(k)}

    @class_window = Window_Command.new(220, @class_names)
    @class_window.x = 0
    @class_window.y = top_y
    @class_window.height = list_h
    @class_window.index = 0

    @ant_window = Window_Command.new(220, [])
    @ant_window.x = 220
    @ant_window.y = top_y
    @ant_window.height = list_h
    @ant_window.index = 0

    @confirm_window = Window_Command.new(200, ["Confirmar", "Voltar"])
    @confirm_window.x = 440
    @confirm_window.y = top_y
    @confirm_window.height = 128
    @confirm_window.visible = false
    @confirm_window.active = false

    @desc_window = Window_RMDesc.new(0, top_y + list_h, 640, 96)

    @phase = :class
    refresh_antecedentes
    refresh_desc

    Graphics.transition
    loop do
      Graphics.update
      Input.update
      update
      break if $scene != self
    end
    Graphics.freeze

    dispose
  end

  def dispose
    @help_window.dispose if @help_window
    @class_window.dispose if @class_window
    @ant_window.dispose if @ant_window
    @confirm_window.dispose if @confirm_window
    @desc_window.dispose if @desc_window
  end

  def update
    @help_window.update
    case @phase
    when :class
      update_class_phase
    when :ante
      update_ante_phase
    when :confirm
      update_confirm_phase
    end
  end

  def current_class_key
    @class_keys[@class_window.index] || @class_keys[0]
  end

  def current_ante_name
    @ante_names[@ant_window.index] || @ante_names[0]
  end

  def refresh_antecedentes
    key = current_class_key
    @ante_names = RM_CharCreate.allowed_for_class(key)
    @ant_window.rm_set_commands(@ante_names)
    @ant_window.index = 0
  end

  def refresh_desc
    key = current_class_key
    ante_name = current_ante_name
    ante = RM_CharCreate.ante_by_name(ante_name)
    ante_id = ante ? ante[:id] : 0
    eff = ante ? ante[:effect] : ""

    t = "Classe: #{key} (#{RM_CharCreate.class_display(key)})\n"
    t += "Antecedente: #{ante_name} (ID #{ante_id})\n"
    t += eff.to_s
    @desc_window.set_text(t)
  end

  def update_class_phase
    @class_window.active = true
    @ant_window.active = false
    @confirm_window.active = false
    @confirm_window.visible = false

    old_index = @class_window.index
    @class_window.update

    if @class_window.index != old_index
      refresh_antecedentes
      refresh_desc
    end

    if Input.trigger?(Input::C)
      $game_system.se_play($data_system.decision_se)
      @phase = :ante
      refresh_desc
    elsif Input.trigger?(Input::B)
      $game_system.se_play($data_system.cancel_se)
      $scene = Scene_Title.new
    end
  end

  def update_ante_phase
    @class_window.active = false
    @ant_window.active = true
    old_index = @ant_window.index
    @ant_window.update

    refresh_desc if @ant_window.index != old_index

    if Input.trigger?(Input::B)
      $game_system.se_play($data_system.cancel_se)
      @phase = :class
      refresh_desc
    elsif Input.trigger?(Input::C)
      $game_system.se_play($data_system.decision_se)
      @phase = :confirm
      @confirm_window.visible = true
      @confirm_window.active = true
      @confirm_window.index = 0
    end
  end

  def update_confirm_phase
    @class_window.active = false
    @ant_window.active = false
    @confirm_window.update

    if Input.trigger?(Input::B)
      $game_system.se_play($data_system.cancel_se)
      @phase = :ante
      @confirm_window.visible = false
      @confirm_window.active = false
    elsif Input.trigger?(Input::C)
      if @confirm_window.index == 0
        apply_selection
        start_game
      else
        $game_system.se_play($data_system.cancel_se)
        $scene = Scene_Title.new
      end
    end
  end

  def apply_selection
    key = current_class_key
    ante_name = current_ante_name
    ante = RM_CharCreate.ante_by_name(ante_name)
    $game_system.rm_class_key = key
    $game_system.rm_antecedente_id = ante ? ante[:id] : 0
    RM_CharCreate.apply_loadout(key, $game_system.rm_antecedente_id)
  end

  def start_game
    # Inicia no mapa inicial canônico do database
    $game_map.setup($data_system.start_map_id)
    $game_player.moveto($data_system.start_x, $data_system.start_y)
    $game_player.refresh
    $scene = Scene_Map.new
  end
end

# Hook: intercepta New Game e abre criação antes do mapa
$rm_char_create_title_hooked ||= false
if !$rm_char_create_title_hooked
  $rm_char_create_title_hooked = true
  class Scene_Title
    alias rm_char_create_command_new_game command_new_game
    def command_new_game
      $game_system.se_play($data_system.decision_se)
      Audio.bgm_stop
      Graphics.frame_count = 0
      $game_temp = Game_Temp.new
      $game_system = Game_System.new
      $game_switches = Game_Switches.new
      $game_variables = Game_Variables.new
      $game_self_switches = Game_SelfSwitches.new
      $game_screen = Game_Screen.new
      $game_actors = Game_Actors.new
      $game_party = Game_Party.new
      $game_troop = Game_Troop.new
      $game_map = Game_Map.new
      $game_player = Game_Player.new
      $scene = Scene_CharacterCreate.new
    end
  end
end
