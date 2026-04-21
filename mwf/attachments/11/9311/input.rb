# * Input Module
#   Scripter : Kyonides-Arkanthos
#   Last Update : 2017-09-24

module Input
  @@buttons = {
    down:        Gosu::KbDown,
    left:        Gosu::KbLeft,
    right:       Gosu::KbRight,
    up:          Gosu::KbUp,
    esc:         Gosu::KbEscape,
    q:           Gosu::KbQ,
    enter:       Gosu::KbEnter,
    return:      Gosu::KbReturn,
    spacebar:    Gosu::KbSpace,
    left_alt:    Gosu::KbLeftAlt,
    right_alt:   Gosu::KbRightAlt,
    left_shift:  Gosu::KbLeftShift,
    right_shift: Gosu::KbRightShift,
    left_ctrl:   Gosu::KbLeftControl,
    right_ctrl:  Gosu::KbRightControl,
    left_meta:   Gosu::KbLeftMeta,
    right_meta:  Gosu::KbRightMeta,
    tab:         Gosu::KbTab,
    caps_lock:   57,
    f1:          Gosu::KbF1,
    f2:          Gosu::KbF2,
    f3:          Gosu::KbF3,
    f4:          Gosu::KbF4,
    f5:          Gosu::KbF5,
    f6:          Gosu::KbF6,
    f7:          Gosu::KbF7,
    f8:          Gosu::KbF8,
    f9:          Gosu::KbF9,
    f10:         Gosu::KbF10,
    f11:         Gosu::KbF11,
    f12:         Gosu::KbF12,
    a:           Gosu::KbA,
    b:           Gosu::KbB,
    gp_down:     Gosu::GP_DOWN,
    gp_left:     Gosu::GP_LEFT,
    gp_right:    Gosu::GP_RIGHT,
    gp_up:       Gosu::GP_UP,
    gp_l1:       Gosu::GP_BUTTON_4,
    gp_r1:       Gosu::GP_BUTTON_5,
    gp_l2:       Gosu::GP_BUTTON_6,
    gp_r2:       Gosu::GP_BUTTON_7,
    gp_ok:       Gosu::GP_BUTTON_1,
    gp_cancel:   Gosu::GP_BUTTON_2
  }
  @@hold_id = @@down_id = @@down_ticks = @@up_ticks = 0
  @@ticks_max = 3
  @@last_down_id = @@se = nil
  def button_down(id)
    @@button_up = nil
    @@last_down_id = @@down_id
    @@hold_id = @@down_id = id
    @@up_ticks = @@down_ticks = @@ticks_max if @@down_ticks == 0 or (@@last_down_id != id and @@last_down_id != @@hold_id)
  end

  def button_up(id)
    @@hold_id = 0 if !@@down_id or @@down_id == 0
    @@up_ticks = @@down_id = 0
    @@button_up = true
  end

  def press_enter?
    return if Gosu::button_down?(@@buttons[:left_alt]) or Gosu::button_down?(@@buttons[:right_alt])
    return true if button_down?(:enter) or button_down?(:return)
    return true if button_down?(:spacebar) or button_down?(:gp_ok)
  end
  def press_quit?() button_down?(:esc) or button_down?(:q) or button_down?(:gp_cancel) end
  def press_up?() button_down?(:up) or button_down?(:gp_up) end
  def press_down?() button_down?(:down) or button_down?(:gp_down) end
  def press_left?() button_down?(:left) or button_down?(:gp_left) end
  def press_right?() button_down?(:right) or button_down?(:gp_right) end
  def press_L1?() button_down?(:gp_l1) end
  def press_R1?() button_down?(:gp_r1) end
  def press_L2?() button_down?(:gp_l2) end
  def press_R2?() button_down?(:gp_r2) end
  def button_down?(id) @@buttons[id] == @@down_id and @@down_ticks > 1 end
  def move_up?() Gosu::button_down?(@@buttons[:up]) or Gosu::button_down?(@@buttons[:gp_up]) end
  def move_down?() Gosu::button_down?(@@buttons[:down]) or Gosu::button_down?(@@buttons[:gp_down]) end
  def move_left?() Gosu::button_down?(@@buttons[:left]) or Gosu::button_down?(@@buttons[:gp_left]) end
  def move_right?() Gosu::button_down?(@@buttons[:right]) or Gosu::button_down?(@@buttons[:gp_right]) end
  def self::[](sym) @@buttons[sym] end
  def hold_up?() hold_button?(:up) or hold_button?(:gp_up) end
  def hold_down?() hold_button?(:down) or hold_button?(:gp_down) end
  def hold_left?() hold_button?(:left) or hold_button?(:gp_left) end
  def hold_right?() hold_button?(:right) or hold_button?(:gp_right) end
  def hold_L1?() hold_button?(:gp_l1) end
  def hold_R1?() hold_button?(:gp_r1) end
  def hold_button?(id) @@buttons[id] == @@hold_id and @@up_ticks == 0 and !@@button_up end
end