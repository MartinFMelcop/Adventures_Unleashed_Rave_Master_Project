# RM_DEBUG_HOTKEYS_RUNTIME.rb
# rm_rgss_spec: 1
# purpose: atalhos de debug (F6/F7/F8) para abrir UIs sem mexer no menu base.
# compatible: RGSS1
#
# Nota: só funciona se Input::F6/F7/F8 existirem neste runtime; caso contrário, é no-op.

module RM_DebugHotkeys
  def self._key?(sym)
    return false unless defined?(Input)
    return false unless Input.const_defined?(sym)
    Input.trigger?(Input.const_get(sym))
  rescue
    false
  end

  def self.update
    if _key?(:F6)
      RM_UI.open_passive
    elsif _key?(:F7)
      RM_UI.open_skills
    elsif _key?(:F8)
      RM_UI.open_journal
    end
  rescue
  end
end

if defined?(Scene_Map)
  class Scene_Map
    alias rm__update__hotkeys_orig update
    def update
      rm__update__hotkeys_orig
      RM_DebugHotkeys.update
    rescue
    end
  end
end
