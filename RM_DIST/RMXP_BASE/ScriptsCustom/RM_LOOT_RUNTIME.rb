# RM_LOOT_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: runtime placeholder para loot por chunk.
# compatible: RGSS1

module RM_Loot
  def self.loot_for_chunk(chunk_key)
    rows = RM_Data.csv_rows('Data/RM_CSV/ACT1_LOOT_BY_CHUNK_CANON.csv')
    rows.select { |r| (r['ChaveMapa'] || r['ChunkKey'] || '') == chunk_key }
  rescue
    []
  end
end
