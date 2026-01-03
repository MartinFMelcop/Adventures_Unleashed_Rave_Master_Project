# =========================================
# 90 - Dev / Debug Tools (RGSS / RPGXP)
# Requer: 00 - Core (core_extensions.rb)
# =========================================
module DebugTools
  module_function

  # Envolve um bloco (ex.: Main) para capturar exceções e logar
  def wrap_main(label = 'Main', &block)
    log_info("== #{label} start ==")
    begin
      block.call
    rescue => e
      log_error("Unhandled Exception in #{label}: #{e} (#{e.class})")
      begin
        bt = e.backtrace || []
        log_error(bt.join("\n"))
      rescue
      end
      # Reexiba a exceção para não mascarar em DEV
      raise e
    ensure
      log_info("== #{label} end ==")
    end
  end

  # Marca início/fim de uma seção relevante nos logs
  def log_section(title)
    log_info("-- #{title} --")
    begin
      yield
    ensure
      log_info("-- end #{title} --")
    end
  end
end

# FPS Meter básico (texto no canto superior esquerdo)
class Sprite_FPSMeter
  UPDATE_INTERVAL = 60 # frames

  def initialize(vp = nil)
    @viewport = vp
    @sprite = Sprite.new(@viewport)
    @sprite.z = 9999
    @sprite.bitmap = Bitmap.new(96, 24)
    @sprite.bitmap.font.size = 16
    @frame_acc = 0
    @last_count = Graphics.frame_count
    @last_fps = 0
    redraw
  end

  def dispose
    if @sprite
      @sprite.bitmap.dispose if @sprite.bitmap
      @sprite.dispose
      @sprite = nil
    end
  end

  def update
    @frame_acc += 1
    if @frame_acc >= UPDATE_INTERVAL
      now = Graphics.frame_count
      frames = now - @last_count
      @last_count = now
      # Aproximação de FPS real (assumindo frame_rate ~ 40)
      @last_fps = frames * (Graphics.frame_rate.to_f / UPDATE_INTERVAL.to_f)
      @frame_acc = 0
      redraw
    end
  end

  def redraw
    bmp = @sprite.bitmap
    bmp.clear
    bmp.fill_rect(0, 0, bmp.width, bmp.height, Color.new(0, 0, 0, 120))
    text = "FPS: %02d" % @last_fps.to_i
    bmp.draw_text(0, 0, bmp.width, bmp.height, text)
  end
end

# Exemplo de integração (manual, em uma cena sua):
# class Scene_Map
#   alias :__fps_start_main :main
#   def main
#     meter = nil
#     if RMXPCore::Config::DEBUG
#       meter = Sprite_FPSMeter.new
#     end
#     DebugTools.log_section('Scene_Map') do
#       __fps_start_main
#     end
#   ensure
#     meter.dispose if meter
#   end
# end
