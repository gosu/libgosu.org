# * Map Module Script
#   Scripter : Kyonides-Arkanthos
#   Last Update : 2017-09-29

module Map
  @id = 0
  @sign_x = 0
  @sign_y = 0
  @events = []
  class << self
    attr_accessor :id, :sign_x, :sign_y, :event
    attr_reader :events
  end
  module_function
  def now() @map end
  def bgm() @map.bgm end
  def name() @map.name end
  def region() @map.region end
  def price_increase() @map.price_increase end
  def width() @map.width end
  def height() @map.height end
  def columns() @map.columns end
  def rows() @map.rows end
  def tileset() @map.tileset end
  def bottom_layer() @map.bottom_layer.dup end
  def lower_layer() @map.lower_layer.dup end
  def tone() { c: @map.color, alpha: @map.alpha } end
  def sign_pos(kind)
    @sign_x = case kind
    when 0, :left   then 0
    when 1, :center then (Window.width - 250) / 2
    when 2, :right  then Window.width - 250
    end
  end

  def load(new_id=@id)
    @id = new_id
    @events = GameData.events[@id] rescue []
    file = sprintf('maps/map%03d.rbg', new_id)
    if File.exist?(file)
      File.open(file,'rb'){|f| @map = Marshal.load(f) }
      return
    end
    @map = GameMap.new(new_id)
    @map.name = 'The Void'
    @map.region = 'Netherworld'
  end

  def teleport(map_id, x, y, dir=nil)
    player = Players.now# player.xy(x, y, dir)#same_map = @id == map_id#
    load(map_id) unless (same_map = @id == map_id)
    player.visible = nil
    player.clear_steps
    Game.setup(SceneMap, proc: Proc.new { player.xy(x, y, dir) }) unless same_map
  end
end