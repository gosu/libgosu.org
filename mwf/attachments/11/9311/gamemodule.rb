# * Game Module Script
#   Scripter : Kyonides-Arkanthos
#   Last Update : 2017-09-23

module Game
  @@scenes = []
  @default_font = 'High Tower Text'#'Liberation'#'DS-Digital'
  @default_color = Gosu::Color.new(255, 255, 255, 255) rescue nil
  @outline_color = Gosu::Color.new(255, 0, 0, 0) rescue nil
  @ok_se = Gosu::Sample.new('audio/se/Ok.ogg')
  @cancel_se = Gosu::Sample.new('audio/se/Cancel.ogg')
  @cursor_se = Gosu::Sample.new('audio/se/Cursor.ogg')
  @page_se = Gosu::Sample.new('audio/se/PageFlip.ogg')
  @wrong_se = Gosu::Sample.new('audio/se/Wrong.ogg')
  @chest_se = Gosu::Sample.new('audio/se/Chest.ogg')
  @coins_se = Gosu::Sample.new('audio/se/Coins.ogg')
  @teleport_se = Gosu::Sample.new('audio/se/Teleport.ogg')
  @bgm = nil
  @bgms = []
  @map_bgm_index = 0
  @save_index = 0
  @ticks = 0
  @timer = 0
  @team_id = 1
  @map_id = 1
  @first_x = 12
  @first_y = 6
  @parties = {}
  @heroes = {}
  @lost_heroes = [] # collects Heroes' ID's
  @party = nil
  @player = nil
  @monsters = []
  @settings = nil
  class << self
    attr_accessor :scene, :bgm, :team_id, :first_x, :first_y
    attr_accessor :lost_heroes, :default_font, :default_color, :outline_color
    attr_reader :switch_scenes, :timer, :map_id, :settings, :parties, :heroes, :monsters, :teleport_se
    attr_reader :ok_se, :cancel_se, :cursor_se, :wrong_se, :chest_se, :coins_se, :page_se
    attr_writer :save_index, :switch_scene
  end
  module_function
  def setup(new_scene, **options)
    stop_bgm
    scene = new_scene.new
    unless scene.kind == :title#@scene = @@scenes.shift if @@scenes[0].class == scene.class
      @@scenes << scene#options.merge!(scene: scene, last_scene: @scene)
      @switch_scenes = [@scene, scene]
      @scene = SceneTransition.new(options)
    else
      @scene = scene
      @scene.setup(options)
    end
  end

  def startup_settings
    @timer = @ticks = 0
    @settings = Settings.new
    @settings.player_id = Players.id
    @settings.map_id = Map.id
    @settings.sign_x = Map.sign_x
    @switches = Switches.new
  end

  def update
    @ticks += 1
    if @ticks % 25 == 0
      @timer += 1
      @ticks = 0
    end
    play_next_bgm
    @scene.update
    return unless @switch_scene
    @switch_scenes = @switch_scene = nil
    @scene = @@scenes.last
    @scene.setup_bgm
    @scene.finish_setup if @scene.kind == :map
  end

  def last_scene(**options)
    stop_bgm
    scene = @@scenes.pop
    unless @@scenes.empty?
      @switch_scenes = [scene, @@scenes[-1]]
      @scene = SceneTransition.new(options)#@scene.setup(scene: @@scenes[-1], last_scene: scene)
    else
      @scene = SceneTitle.new
      @scene.setup(options)
    end
  end

  def stop_bgm
    @bgm.stop if @bgm
    return if @bgms.empty?
    @bgms[@bgm_index].stop
    @bgms.clear
    @volume = @bgm_index = nil
  end

  def play_bgm(name, volume=70, non_stop=true)
    name = 'audio/bgm/' + name
    @bgm = Cache.bgm[name] ||= Gosu::Song.new(name)
    @bgm.volume = volume / 100.0
    @bgm.play(non_stop)
  end

  def play_list(volume, names)
    return if !names or names.empty?
    @bgm_index = @scene.kind == :map ? @map_bgm_index : 0
    @volume = volume / 100.0
    names.each do |name|
      name = 'audio/bgm/' + name
      @bgms << bgm = Cache.bgm[name] ||= Gosu::Song.new(name)
      bgm.volume = @volume
    end
    @bgms[@bgm_index].play(@bgms.size == 1)
  end

  def play_next_bgm
    return if @bgms.empty? or @bgms[@bgm_index].playing?
    @bgm_index = (@bgm_index + 1) % @bgms.size
    @map_bgm_index = @bgm_index if @scene.kind == :map
    @bgms[@bgm_index].play(@bgms.size == 1)
  end

  def save_data
    @monsters = @monsters.sort
    @settings.player_id = Players.id
    @settings.map_id = Map.id
    @settings.sign_x = Map.sign_x
    @settings.sign_y = Map.sign_y
    time = [@timer, @ticks]
    index = sprintf("%02d", @save_index+1)
    File.open("saves/game#{index}.rbg",'wb') do |file|
      Marshal.dump(time, file)
      Marshal.dump(@settings, file)
      Marshal.dump(@switches, file)
      Marshal.dump(@lost_heroes, file)
      Marshal.dump(@heroes, file)
      Marshal.dump(@parties, file)
      Marshal.dump(Players.all, file)
      Marshal.dump(@monsters, file)
    end
  end

  def load_data
    filename = sprintf("saves/game%02d.rbg", @save_index+1)
    File.open(filename,'rb') do |file|
      @timer, @ticks = Marshal.load(file)
      @settings = Marshal.load(file)
      @switches = Marshal.load(file)
      @lost_heroes = Marshal.load(file)
      @heroes = Marshal.load(file) rescue {}
      @parties = Marshal.load(file) rescue {}
      Players << Marshal.load(file)
      @monsters = Marshal.load(file) rescue []
    end
    Players.id = @team_id = @settings.player_id
    Map.sign_x = @settings.sign_x
    Map.sign_y = @settings.sign_y
    Map.load(@settings.map_id)
  end

  def temp_load(index)
    data = {}
    filename = sprintf("saves/game%02d.rbg", index+1)
    if File.exist?(filename)
      File.open(filename,'rb') do |file|
        data[:time] = Marshal.load(file)
        data[:settings] = Marshal.load(file)
        switches = Marshal.load(file)
        lost_heroes = Marshal.load(file)
        heroes = Marshal.load(file)
        data[:parties] = Marshal.load(file)
        players = Marshal.load(file)
        data[:monsters] = Marshal.load(file).size rescue 0
      end
      data[:chests] = data[:settings].chests.size
    else
      @settings.player_id = Players.id
      @settings.map_id = Map.id
      data[:settings] = @settings
      data[:parties] = Game.parties
      data[:monsters] = @monsters.size
      data[:chests] = @settings.chests.size
      data[:time] = [@timer, @ticks]
    end
    data
  end
  def starting?() @@scenes.size == 1 and @@scenes[0].kind != :map end
  def party() @parties[@team_id] end
  def terms(kind) TERMS[kind][KUnits.lang] end
end

module Players
  @id = 1
  @players = {}
  module_function
  def id() @id end
  def id=(new_id) @id = new_id end
  def now() @players[@id] end
  def clear() @players = {} end
  def all() @players end
  def all=(new_players) @players = new_players end
  def <<(new_players) @players = new_players end
  def [](index) @players[index] end
  def []=(index, new_player) @players[index] = new_player end
  def size() @players.size end
  def each() @players.each {|player| yield player } end
end