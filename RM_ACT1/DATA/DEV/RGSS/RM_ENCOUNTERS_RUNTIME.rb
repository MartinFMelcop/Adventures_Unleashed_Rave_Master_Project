# RM_ENCOUNTERS_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: runtime placeholder para tabelas de encontro (por MapType/chunk).
# compatible: RGSS1

module RM_Encounters
  def self.table_by_maptype(maptype)
    rows = RM_Data.csv_rows('Data/RM_CSV/ACT1_ENCOUNTERS_BY_MAPTYPE_CANON.csv')
    rows.select { |r| (r['MapType'] || '') == maptype }
  rescue
    []
  end
end
