# RM_PROLOGUE_SLIDESHOW_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: slideshow introdutório não-jogável com opção de avançar/pular
# compatible: RGSS1 (Ruby 1.8 / RPG Maker XP)
# notes:
# - Usa Graphics.transition e Window_Help para mostrar texto breve.
# - Safe fallback: se assets não existirem, exibe apenas texto em tela preta.

module RM_PrologueSlideshow
  SLIDES = [
    {:id => "SLD-PRLG-01", :texto => "Capital de Rose: rumores de guerra e um chamado aos aventureiros.", :wait => 120},
    {:id => "SLD-PRLG-02", :texto => "A Guilda convoca novos recrutas. Você é um deles.", :wait => 120},
    {:id => "SLD-PRLG-03", :texto => "Um mentor misterioso fala sobre a Anomalia do Véu.", :wait => 120}
  ]

  def self.play_once
    viewport = Viewport.new(0, 0, 640, 480)
    window = Window_Help.new
    window.y = 160
    window.opacity = 200
    window.back_opacity = 200
    window.contents_opacity = 255

    SLIDES.each do |slide|
      Graphics.transition(10)
      window.set_text(slide[:texto])
      frames = slide[:wait]
      loop do
        Graphics.update
        Input.update
        break if Input.trigger?(Input::C) || Input.trigger?(Input::B) || frames <= 0
        frames -= 1
      end
      break if Input.trigger?(Input::B)
    end
  ensure
    window.dispose if window && !window.disposed?
    viewport.dispose if viewport && !viewport.disposed?
    Graphics.freeze
  end
end
