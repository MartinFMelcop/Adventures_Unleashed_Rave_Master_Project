# RM_LIGHTING_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: overlay escuro + máscara de luz em cavernas.
# compatible: RGSS1
#
# Nota: implementação leve. Se assets não existirem, o script falha silenciosamente.

module RM_Lighting
  def self.enabled?
    RM_WorldContext.is_cave?
  end
end

if defined?(Spriteset_Map)
  class Spriteset_Map
    alias rm__update__light_orig update
    alias rm__dispose__light_orig dispose

    def rm_init_lighting
      return if @rm_dark_sprite
      @rm_dark_sprite = Sprite.new(@viewport1)
      @rm_dark_sprite.z = 9999
      @rm_dark_sprite.bitmap = Bitmap.new(640, 480)
      @rm_dark_sprite.bitmap.fill_rect(0, 0, 640, 480, Color.new(0,0,0,180))

      @rm_light_sprite = Sprite.new(@viewport1)
      @rm_light_sprite.z = 10000
      @rm_light_sprite.blend_type = 2  # subtraction
      if File.exist?('Graphics/Pictures/RM_LIGHT_CIRCLE.png')
        @rm_light_sprite.bitmap = Bitmap.new('Graphics/Pictures/RM_LIGHT_CIRCLE.png')
      else
        # fallback: pequeno círculo simples
        @rm_light_sprite.bitmap = Bitmap.new(128,128)
        @rm_light_sprite.bitmap.fill_rect(0,0,128,128, Color.new(255,255,255,120))
      end
      @rm_light_sprite.ox = @rm_light_sprite.bitmap.width / 2
      @rm_light_sprite.oy = @rm_light_sprite.bitmap.height / 2
    rescue
    end

    def update
      rm__update__light_orig
      if RM_Lighting.enabled?
        rm_init_lighting
        if @rm_dark_sprite
          @rm_dark_sprite.visible = true
          @rm_light_sprite.visible = true
          # seguir player
          if $game_player
            @rm_light_sprite.x = $game_player.screen_x
            @rm_light_sprite.y = $game_player.screen_y
          end
        end
      else
        if @rm_dark_sprite
          @rm_dark_sprite.visible = false
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
    rescue
    end
  end
end
