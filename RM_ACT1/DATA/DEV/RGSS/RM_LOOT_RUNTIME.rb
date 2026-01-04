# RM_LOOT_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: runtime placeholder para loot por chunk.
# compatible: RGSS1

module RM_Loot
  LOOT_PATHS = [
    'Data/RM_CSV/ACT1_LOOT_BY_CHUNK_CANON.csv',
    'Data/ACT1_LOOT_BY_CHUNK_CANON.csv',
    'RM_ACT1/DATA/CORE/ACT1_LOOT_BY_CHUNK_CANON.csv'
  ]

  def self.loot_rows
    LOOT_PATHS.each do |path|
      rows = RM_Data.csv_rows(path)
      return rows unless rows.empty?
    end
    []
  end

  def self.loot_for_chunk(chunk_key)
    return [] if chunk_key.nil? || chunk_key == ''
    loot_rows.select do |r|
      key = r['ChaveMapa'] || r['ChunkKey'] || ''
      key == chunk_key
    end
  rescue
    []
  end
end
