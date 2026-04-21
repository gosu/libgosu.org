# * Basic Additions - Loading Bitmaps, Calendar, String, Locate, Input, Color, Rect, Fake Viewport
#   Scripter : Kyonides-Arkanthos
#   2017-09-24

module Window
  @window = nil
  module_function
  def <<(new_window) @window = new_window end
  def now() @window end
  def close() @window.close end
  def width() @window.width end
  def height() @window.height end
  def fullscreen?() @window.fullscreen? end
  def fullscreen=(boolean) @window.fullscreen = boolean end
  def toggle_fullscreen() @window.fullscreen = !@window.fullscreen? end
end

module Load
  module_function
  def character(filename, w=-4, h=-4)
    filename = 'images/characters/' + filename + '.png'
    Gosu::Image.load_tiles(filename, w, h, tileable: true)
  end

  def icon_tiles(filename, w=8, h=8)
    filename = 'images/icons/' + filename + '.png'
    Gosu::Image.load_tiles(filename, w, h, tileable: true) rescue nil
  end

  def picture_tiles(filename, w=32, h=32)
    filename = 'images/pictures/' + filename + '.png'
    Gosu::Image.load_tiles(filename, w, h, tileable: true) rescue nil
  end

  def map_tiles(filename, w, h)
    filename = 'images/tilesets/' + filename + '.png'
    Gosu::Image.load_tiles(filename, w, h, tileable: true) rescue nil
  end
  def backdrop(filename) Gosu::Image.new('images/backdrops/' + filename + '.png') end
  def icon(filename) Gosu::Image.new('images/icons/' + filename + '.png') end
  def battler(filename) Gosu::Image.new('images/battlers/' + filename + '.png') end
  def face(filename) Gosu::Image.new('images/faces/' + filename + '.png') end
  def picture(filename, **options) Gosu::Image.new('images/pictures/' + filename + '.png', options) end
  def tilemap(filename) Gosu::Image.new('images/maps/' + filename + '.png') end
  def book_page(filename) Gosu::Image.new('images/books/' + filename + '.png') end
end

module Calendar
  module Names
    Days = { nil => '---------', 0 => 'Sunday',    1 => 'Monday',
             2 => 'Tuesday',     3 => 'Wednesday', 4 => 'Thursday',
             5 => 'Friday',      6 => 'Saturday'  }
    DaysShort = { nil => '---', 0 => 'SUN', 1 => 'MON', 2 => 'TUE',
               3 => 'WED',   4 => 'THU', 5 => 'FRI', 6 => 'SAT'  }
    Months = { 0 => '----------',
               1 => 'January',  2 => 'February',  3 => 'March',
               4 => 'April',    5 => 'May',       6 => 'June',
               7 => 'July',     8 => 'August',    9 => 'September',
              10 => 'October', 11 => 'November', 12 => 'December'  }
    MonthsShort = { 0 => '---',
               1 => 'JAN',  2 => 'FEB',  3 => 'MAR',
               4 => 'APR',  5 => 'MAY',  6 => 'JUN',
               7 => 'JUL',  8 => 'AUG',  9 => 'SEP',
              10 => 'OCT', 11 => 'NOV', 12 => 'DEC'  }
  end
end

module Cache
  @bgm = {}
  @bg = {}
  @maps = {}
  @boxes = {}
  @icons = {}
  @tiles = {}
  @icon_tiles = {}
  class << self
    attr_reader :bgm, :bg, :maps, :boxes, :icons, :icon_tiles
    def include_tiles?(new_tiles) @tiles.keys.include?(new_tiles) end
    def [](key) @tiles[key] end
    def []=(key,tiles) @tiles[key] = tiles end
    def clear
      @bg.clear
      @boxes.clear
      @icons.clear
      @tiles.clear
      @icon_tiles.clear
    end
  end
end

module Locate
  def xyz(x, y, z) @x, @y, @z = x, y, z end
end

module Color
  @kind = {
    system:       Gosu::Color.new(255,0,255,255),#Aqua
    alert:        Gosu::Color.new(255,255,0,0),#Red
    orange:       Gosu::Color.new(255,249,165,3),
    warning:      Gosu::Color.new(255,255,255,0),#Yellow
    green:        Gosu::Color.new(255,0,220,0),
    leavegreen:   Gosu::Color.new(255,140,200,0),
    darkgreen:    Gosu::Color.new(255,0,120,0),
    skyblue:      Gosu::Color.new(200,180,255,255),
    frozen:       Gosu::Color.new(255,0,0,255),#Blue
    fuchsia:      Gosu::Color.new(255,255,0,255),
    brown:        Gosu::Color.new(255,100,73,52),
    black:        Gosu::Color.new(255,0,0,0),
    gray:         Gosu::Color.new(255,80,80,80),
    white:        Gosu::Color.new(255,255,255,255),
    void:         Gosu::Color.new(0,0,0,0),
    yellowgreen:  Gosu::Color.new(255,154,205,50), # YellowGreen
    springgreen:  Gosu::Color.new(160,255,127,0), # Orange?
    purple:       Gosu::Color.new(255,170,85,255),
    silver:       Gosu::Color.new(255,192,192,192),# Silver?
    turquoise:    Gosu::Color.new(64,224,208,0),
    violet:       Gosu::Color.new(238,130,238,0),
    midnightblue: Gosu::Color.new(25,25,112,0),
    mintcream:    Gosu::Color.new(245,255,250,0)
  }
  def self::[](symbol) @kind[symbol] end
end

module Gosu
  class << self
    alias :down? :button_down?
  end
end

class String
  alias kyon_string_concat concat
  def concat(string) kyon_string_concat(string.to_s) end
  def to_a
    ary = []
    size.times {|n| ary << self[n] }
    ary.gsub(/\[|\]/,'')
  end
end

class Rect
  attr_accessor :x, :y
  attr_reader :width, :height
  def initialize(x, y, width, height)
    @x, @y, @width, @height = x, y, width, height
  end
  def dimensions() [@x, @y, @width, @height] end
end

class Viewport < Rect
  attr_reader :horizontal, :vertical
  def initialize(x, y, width, height)
    super
    @horizontal = @x..(@x + @width)
    @vertical = @y..(@y + @height)
  end
  def visible?(x, y) @horizontal.include?(x) and @vertical.include?(y) end
end