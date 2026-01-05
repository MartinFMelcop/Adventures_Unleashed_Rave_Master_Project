# RM_WORLD_CONTEXT_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: Mantém contexto global (chunk atual / cave flag) + helpers de leitura de CSV.
# compatible: RGSS1 (Ruby 1.8 / RPG Maker XP)

module RM_Data
  def self.safe_read(path)
    return nil unless File.exist?(path)
    File.read(path)
  rescue
    nil
  end

  # CSV simples (sem aspas/escapes avançados). Retorna array de hashes.
  def self.csv_rows(path)
    raw = safe_read(path)
    return [] if raw.nil? || raw.strip == ''
    lines = raw.split(/\r?\n/)
    return [] if lines.empty?
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
    []
  end
end

module RM_WorldContext
  def self._ensure
    if $game_system.nil?
      return
    end
    if !$game_system.instance_variable_defined?(:@rm_world_ctx) || $game_system.instance_variable_get(:@rm_world_ctx).nil?
      $game_system.instance_variable_set(:@rm_world_ctx, {:chunk_key=>nil, :is_cave=>false})
    end
  end

  def self.set_chunk(chunk_key)
    _ensure
    ctx = $game_system.instance_variable_get(:@rm_world_ctx)
    ctx[:chunk_key] = chunk_key
    begin
      RM_QuestProgress.record_trigger('EnterArea', chunk_key) if defined?(RM_QuestProgress)
    rescue
    end
  end

  def self.chunk
    _ensure
    ctx = $game_system.instance_variable_get(:@rm_world_ctx)
    ctx[:chunk_key]
  end

  def self.set_cave(flag)
    _ensure
    ctx = $game_system.instance_variable_get(:@rm_world_ctx)
    ctx[:is_cave] = (flag ? true : false)
  end

  def self.is_cave?
    _ensure
    ctx = $game_system.instance_variable_get(:@rm_world_ctx)
    ctx[:is_cave] == true
  end
end
