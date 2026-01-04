# RM_LIGHTING_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: overlay escuro + máscara de luz em cavernas.
# compatible: RGSS1
#
# Nota: implementação leve. Se assets não existirem, o script falha silenciosamente.

module RM_Lighting
  DEFAULT_CONFIG = {
    :darkness_alpha => 180,
    :player_radius => 128
  }

  @config_by_map = nil
  @light_kernel = nil
  @event_sources = {}
  @cached_switch_ids = {}

  PLAYER_LIGHT_SWITCHES = {
    :lantern => ['S_LANTERNA_ATIVA', 'S_LIGHT_LANTERN'],
    :torch   => ['S_ITEM_TOCHA_ATIVA', 'S_LIGHT_TORCH']
  }

  PLAYER_LIGHT_BONUS = {
    :lantern => 160,
    :torch   => 96
  }

  def self.config_path_candidates
    [
      'Data/RM_CAVE_LIGHTING_CONFIG.csv',
      'RM_ACT1/DATA/DEV/CAVE_LIGHTING_CONFIG.csv'
    ]
  end

  def self.load_config!
    return if @config_by_map
    @config_by_map = {}
    path = config_path_candidates.find { |p| File.exist?(p) }
    rows = path ? RM_Data.csv_rows(path) : []
    rows.each do |r|
      map_id = (r['MapID'] || '').to_i
      key = map_id > 0 ? map_id : nil
      chunk = (r['ChunkKey'] || '').strip
      next if key.nil? && chunk == ''
      @config_by_map[key] ||= {}
      @config_by_map[key][:chunk_key] = chunk unless chunk == ''
      @config_by_map[key][:darkness_alpha] = (r['DarknessAlpha'] || '').to_i if r['DarknessAlpha'] && r['DarknessAlpha'] != ''
      @config_by_map[key][:player_radius] = (r['PlayerRadius'] || '').to_i if r['PlayerRadius'] && r['PlayerRadius'] != ''
    end
  rescue
    @config_by_map = {}
  end

  def self.profile_for(map_id)
    load_config!
    profile = @config_by_map[map_id] if @config_by_map
    profile ||= @config_by_map[nil] if @config_by_map && @config_by_map.key?(nil)
    profile
  end

  def self.enabled?(map_id=nil)
    profile = profile_for(map_id)
    return true if profile
    RM_WorldContext.is_cave?
  end

  def self.ensure_kernel
    return if @light_kernel
    if File.exist?('Graphics/Pictures/RM_LIGHT_CIRCLE.png')
      @light_kernel = Bitmap.new('Graphics/Pictures/RM_LIGHT_CIRCLE.png')
    else
      @light_kernel = Bitmap.new(64, 64)
      center = 32
      radius = 32.0
      (0...64).each do |y|
        (0...64).each do |x|
          dx = x - center
          dy = y - center
          dist = Math.sqrt(dx * dx + dy * dy)
          next if dist > radius
          alpha = [[(radius - dist) * 6, 0].max, 200].min
          @light_kernel.set_pixel(x, y, Color.new(255, 255, 255, alpha))
        end
      end
    end
  rescue
    @light_kernel = nil
  end

  def self.register_event_light(event, radius=128, offset_x=0, offset_y=0)
    return if event.nil?
    @event_sources[event.id] = {:event => event, :radius => radius.to_i, :ox => offset_x.to_i, :oy => offset_y.to_i}
  rescue
  end

  def self.clear_event_light(event)
    return if event.nil?
    @event_sources.delete(event.id)
  rescue
  end

  def self.reset_events!
    @event_sources = {}
  end

  def self.resolve_switch_id(name)
    return nil if $data_system.nil? || $data_system.switches.nil?
    return @cached_switch_ids[name] if @cached_switch_ids.key?(name)
    @cached_switch_ids[name] = $data_system.switches.index(name)
  end

  def self.player_light_bonus
    PLAYER_LIGHT_SWITCHES.each do |kind, names|
      names.each do |sw_name|
        idx = resolve_switch_id(sw_name)
        next if idx.nil?
        return PLAYER_LIGHT_BONUS[kind] if $game_switches && $game_switches[idx]
      end
    end
    0
  rescue
    0
  end
end

if defined?(Game_Map)
  class Game_Map
    alias rm__setup__lighting_ctx_orig setup
    def setup(map_id)
      RM_Lighting.load_config!
      profile = RM_Lighting.profile_for(map_id)
      if profile && profile[:chunk_key]
        RM_WorldContext.set_chunk(profile[:chunk_key])
        RM_WorldContext.set_cave(true)
      elsif profile
        RM_WorldContext.set_cave(true)
      else
        RM_WorldContext.set_cave(false)
      end
      rm__setup__lighting_ctx_orig(map_id)
    rescue
    end
  end
end

if defined?(Spriteset_Map)
  class Spriteset_Map
    alias rm__update__light_orig update
    alias rm__dispose__light_orig dispose

    def rm_init_lighting
      return if @rm_dark_sprite
      RM_Lighting.ensure_kernel
      @rm_light_sources = {}
      @rm_dark_sprite = Sprite.new(@viewport1)
      @rm_dark_sprite.z = 9999
      @rm_dark_sprite.bitmap = Bitmap.new(640, 480)

      @rm_light_sprite = Sprite.new(@viewport1)
      @rm_light_sprite.z = 10000
      @rm_light_sprite.bitmap = Bitmap.new(640, 480)
      @rm_light_sprite.blend_type = 2  # subtraction
      @rm_light_sprite.ox = 0
      @rm_light_sprite.oy = 0
    rescue
    end

    def rm_update_light_bitmap(profile)
      return if @rm_light_sprite.nil?
      bmp = @rm_light_sprite.bitmap
      bmp.clear
      kernel = RM_Lighting.instance_variable_get(:@light_kernel)
      return if kernel.nil?

      sources = []
      if $game_player
        radius = (profile[:player_radius] || RM_Lighting::DEFAULT_CONFIG[:player_radius]).to_i
        radius += RM_Lighting.player_light_bonus
        sources << [:player, $game_player.screen_x, $game_player.screen_y, radius]
      end
      RM_Lighting.instance_variable_get(:@event_sources).each_value do |src|
        evt = src[:event]
        next if evt.nil?
        sources << [:event, evt.screen_x + src[:ox], evt.screen_y + src[:oy], src[:radius]]
      end

      sources.each do |(_, x, y, radius)|
        next if radius <= 0
        scale_rect = Rect.new(0, 0, radius * 2, radius * 2)
        dest_rect = Rect.new(x - radius, y - radius, radius * 2, radius * 2)
        bmp.stretch_blt(dest_rect, kernel, scale_rect, 255)
      end
    rescue
    end

    def rm_apply_darkness(profile)
      alpha = profile[:darkness_alpha] || RM_Lighting::DEFAULT_CONFIG[:darkness_alpha]
      alpha = [[alpha.to_i, 0].max, 255].min
      @rm_dark_sprite.bitmap.clear
      @rm_dark_sprite.bitmap.fill_rect(0, 0, 640, 480, Color.new(0,0,0,alpha))
    rescue
    end

    def rm_tick_lighting
      profile = RM_Lighting.profile_for($game_map ? $game_map.map_id : nil)
      return false unless RM_Lighting.enabled?($game_map ? $game_map.map_id : nil)
      rm_init_lighting
      return false if @rm_dark_sprite.nil? || @rm_light_sprite.nil?
      @rm_dark_sprite.visible = true
      @rm_light_sprite.visible = true
      rm_apply_darkness(profile || RM_Lighting::DEFAULT_CONFIG)
      rm_update_light_bitmap(profile || RM_Lighting::DEFAULT_CONFIG)
      true
    rescue
      false
    end

    def update
      rm__update__light_orig
      active = rm_tick_lighting
      unless active
        if @rm_dark_sprite
          @rm_dark_sprite.visible = false
        end
        if @rm_light_sprite
          @rm_light_sprite.visible = false
        end
      end
    rescue
    end

    def dispose
      rm__dispose__light_orig
      if @rm_dark_sprite
        @rm_dark_sprite.bitmap.dispose rescue nil
        @rm_dark_sprite.dispose rescue nil
      end
      if @rm_light_sprite
        @rm_light_sprite.bitmap.dispose rescue nil
        @rm_light_sprite.dispose rescue nil
      end
      RM_Lighting.reset_events!
    rescue
    end
  end
end
