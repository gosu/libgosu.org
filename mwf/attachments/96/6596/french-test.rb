# Encoding: UTF-8

require 'rubygems'
require 'gosu'

class FrenchTest < Gosu::Window
  def draw
    @font ||= Gosu::Font.new(self, Gosu::default_font_name, 20)
    @font.draw "It was first used for the sound of the voiceless alveolar", 10, 10, 0
    @font.draw "affricate /ts/ in old Spanish and stems from the Visigothic", 10, 40, 0
    @font.draw "form of the letter \"z\". Spanish has not used this symbol", 10, 70, 0
    @font.draw "since an orthographic reform in the 18th century (which replaced \"ç\"", 10, 100, 0
    @font.draw "with the now-devoiced \"z\").", 10, 130, 0
  end
end

FrenchTest.new(600, 200, false).show
