# * Scene Scripts
#   Scripter : Kyonides-Arkanthos
#   Last Update : 2017-10-17

class SceneBase
  include Input
  def initialize
    @ticks = 0
    @window_width = Window.width
    @window_height = Window.height
  end
  def setup(**options) end#def setup_labels() end
  def setup_bgm() end
  def kind() end
  def update_animations() end
  def update
    if @@down_ticks > 0
      @@down_ticks -= 1
      @@down_id = 0 if @@down_ticks == 0
    end
    @@up_ticks -= 1 if @@up_ticks > 0
    update_animations
    return @ticks -= 1 if @ticks > 0
    update_scene
  end
  def draw() @bg.draw(0, 0, 0) end
end

class SceneTransition < SceneBase
  def initialize(**options)
    super()
    @ticks = 41
    @width = -40
    @weather = KUnitsWeather.new(1)
    @color = Color[:black].dup
    @draw_last = true
    @last_scene, @scene = Game.switch_scenes
    unless @last_scene.kind == :map
      @last_draw = Proc.new { @last_scene.draw }
    else
      @last_draw = Proc.new { @last_scene.draw_no_weather(@last_scene.temp_x, @last_scene.temp_y) }
    end
    unless @scene.kind == :map
      @new_draw = Proc.new { @scene.draw }
    else
      @new_draw = Proc.new { @scene.draw_no_weather(@scene.temp_x, @scene.temp_y) }
    end
    @scene.setup(options)
  end

  def update
    @weather.update
    if @draw_last
      @draw_last = nil if @width == 800
      @width += 40 if @ticks > 20
    else
      @width -= 40 if @ticks < 21
    end
    return @ticks -= 1 if @ticks > 0 or @width > 0
    @last_draw = @new_draw = nil
    Game.switch_scene = true
  end

  def draw
    begin
      @draw_last ? @last_draw.call : @new_draw.call
      38.times do |n|
        x = n % 2 == 0 ? 0 : @window_width - @width
        Gosu.draw_rect(x, n * 16, @width, 16, @color, 1050)
      end
    rescue
      #@last_scene.draw
    end
    @weather.draw
  end
end

class SceneTitle < SceneBase
  def kind() :title end
  def setup(index: 0)
    Game.play_bgm(KUnits::TITLE_BGM, 60)
    setup_labels
    @index = index
    @bg = Load.backdrop('nightsky')
    strings = ['Start New Game', 'Load Game', 'Options', 'Just Leave']
    colors = [Gosu::Color::YELLOW, Color[:orange], Color[:orange], Color[:orange]]
    @title_window = WindowOptions.new(290, 310, 220, 140, strings: strings, c: colors)
    x, y, h = @title_window.x, @title_window.y, @title_window.texts[-1].height
    @cursor = CursorUpDown.new(strings.size, x: x, y: y, h: h, index: @index, window: @title_window, show: true)
  end

  def setup_labels
    @title = Text.new(h: 80, text: 'KUnits Gosu', y: 12, a: :center, name: 'High Tower Text')
    text = 'Copyright (c) 2017 - Kyonides'#'DeJaVu Sans' 'Malagua Demo' name: 'High Tower Text'
    @copyright = Text.new(h: 32, text: text, x: 19, y: @window_height - 32, z: 5)
  end

  def update_scene
    return close_window if @cancel
    @cursor.update
    if press_enter?
      Game.ok_se.play
      @title_window.visible = nil
      @cursor.visible = nil
      case @cursor.index
      when 0 then Game.setup(SceneKUnits, max: 4)
      when 1 then Game.setup(SceneKUnitsSave, mode: :load)
      when 2 then Game.setup(SceneOptions)
      else prepare_shutdown
      end
      return
    elsif press_quit?
      Game.cancel_se.play
      prepare_shutdown
    end
  end

  def prepare_shutdown
    @cancel = true
    @ticks = 12
    @title_window.visible = nil
    @cursor.visible = nil
  end

  def draw
    super
    @title.draw_thick_outline
    @copyright.draw_outline
    @title_window.draw
    @cursor.draw
  end

  def close_window
    return unless @cancel and @ticks == 0
    Game.bgm.stop
    puts 'Thank you for playing this demo!', 'Stopped playing music.', "Closing game window now..."
    Window.close
  end
end

class SceneOptions < SceneBase
  def setup(**options)
    Game.play_bgm(KUnits::OPTIONS_BGM, 60)
    @bg = Load.backdrop('bluewaves')#'DS-Digital' 'High Tower Text'
    @texts = Text.new(height: 60, text: 'Game Options', align: :center, y: 16)
  end

  def update
    if press_quit?
      Game.cancel_se.play(0.7)
      @@down_id = 0
      @texts = nil
      Game.last_scene(index: 2)
      return
    elsif press_enter?
      #Game.ok_se.play(0.7)
      #Game.setup(GemRoulette)
    end
  end

  def draw
    super
    @texts.draw_outline
  end
end

class SceneKUnits < SceneBase
  def setup_bgm() Game.play_list(50, KUnits::BGM) end
  def setup(keep: nil, max: 2, id: 1)
    @row_max = KUnits::ACTOR_ROW_MAX
    @perteam = KUnits::ACTORS_PER_TEAM
    @team_cols = KUnits::TEAM_COL_MAX
    @actors = GameData.warriors[1..-1]
    @keep_teams = keep
    @team_max = max
    Players.id = Game.team_id = id
    @teams = {}
    check_unknown_heroes
    @max = @actors.size
    setup_labels
    @stage = @last_y = @team_index = @last_index = @index = @ticks = 0
    @bg = Load.backdrop(KUnits::BACKDROP)
    make_available_heroes
    make_team_background_sprites
    make_team_sprites
    @cursor = Sprite_HorCursor.new('bookmark', @max, @row_max)
    @cursor.dimensions(36, 54)
    @cursor.xyz(4, 32, 5)
    make_hero_stats# font = 'High Tower Text'
    text = KUnits.desc_labels
    desc = @character.desc.empty? ? text[1] : @character.desc
    @desc_box.label(text[0], h: 29, x: 20, y: -8, o: :alert)
    @desc_box.label(desc, h: 26, x: 4, y: 16, o: :frozen)
    labels = KUnits.option_labels
    commands = Game.starting? ? labels[0..2] + [labels[4]] : labels[0..3]
    @options = CommandSpriteset.new(280, 300, 230, commands)
    @options.hide
  end

  def setup_labels
    text = Game.starting? ? 0 : 1
    text = KUnits.titles[text]
    @header = Sprite_Box.new(0, 0, w: @window_width, h: 32, c: Game.outline_color)
    @header.label(text, y: 6, h: 37, a: :center, o: :alert)
    @stage_box = Sprite_Box.new(0, 147, w: 508, h: 26, c: Game.outline_color)
    @stage_box.label(KUnits.stage_labels[2], x: 24, y: 4, h: 31, o: :frozen)
    @stage_box.label(@max, x: 55, y: 4, h: 31, f: 'Footlight MT Light', o: :frozen)
    @stage_box.label(KUnits.stage_labels[0], y: 4, h: 31, a: :center, o: :alert)
    @arrows = Load.icon_tiles('arrows4', -4, -1)
    @arrow = @arrows[0] if @max > 20
    color = Color[:green].dup
    color.alpha = 80
    @stats_box = Sprite_Box.new(508, 32, w: 292, h: 141, c: color)
    color = Color[:black].dup
    color.alpha = 160
    @desc_box = Sprite_Box.new(8, 562, w: 784, h: 40, c: color)
  end
  
  def check_unknown_heroes
    @chosen_actors = []
    @full_teams = [0] * @team_max
    @team_max.times {|n| @teams[n + 1] =  [] }
    return if KUnits.add_heroes.empty?
    KUnits.add_heroes.each do |unit, ids|
      @full_teams[unit - 1] = ids.size
      @chosen_actors += ids.sort
      @teams[unit] += ids
    end
    return if @add_heroes
    @add_heroes = KUnits.add_heroes.values.sort.flatten
    extras = @add_heroes.map {|hid| GameData.warriors[hid] }
    @actors = @actors - extras
  end

  def make_hero_stats
    font = 'Footlight MT Light'
    labels = KUnits.stats_labels
    class_label = GameData.classes[@character.class_id].name
    @stats_box.label(labels[0], h: 30, y: 4, a: :center, c: :system)
    @stats_box.label(@character.name, h: 30, x: 4, y: 24, c: :warning)
    @stats_box.label(labels[1], h: 30, x: 200, y: 24, c: :system)
    @stats_box.label(@character.level, f: font, h: 30, a: :right, y: 24, c: :warning)
    @stats_box.label(labels[2], h: 30, x: 4, y: 48, c: :system)
    @stats_box.label(class_label, h: 30, x: 70, y: 48, c: :warning)
    @stats_box.label(labels[3], h: 30, x: 4, y: 72, c: :system)
    @stats_box.label(@character.hp, f: font, h: 30, x: 45, y: 72, c: :warning)
    @stats_box.label(labels[4], h: 30, x: 94, y: 72, c: :system)
    x1, x2 = [196, 240]
    @stats_box.label(@character.mp, f: font, h: 30, x: 139, y: 72, c: :warning)
    @stats_box.label(labels[5], h: 30, x: x1 + 8, y: 48, c: :system)
    @stats_box.label(@character.ap, f: font, h: 30, x: x2 + 8, y: 48, c: :warning)
    @stats_box.label(labels[6], h: 30, x: x1 + 8, y: 72, c: :system)
    @stats_box.label(@character.sp, f: font, h: 30, x: x2 + 8, y: 72, c: :warning)
    @stats_box.label(labels[7], h: 30, x: 4, y: 96, c: :system)
    @stats_box.label(@character.atk, f: font, h: 30, x: 56, y: 96, c: :warning)
    @stats_box.label(labels[8], h: 30, x: 94, y: 96, c: :system)
    @stats_box.label(@character.matk, f: font, h: 30, x: 146, y: 96, c: :warning)
    @stats_box.label(labels[11], h: 30, x: x1, y: 96, c: :system)
    @stats_box.label(@character.agil, f: font, h: 30, x: x2 + 8, y: 96, c: :warning)
    @stats_box.label(labels[9], h: 30, x: 4, y: 120, c: :system)
    @stats_box.label(@character.pdef, f: font, h: 30, x: 56, y: 120, c: :warning)
    @stats_box.label(labels[10], h: 30, x: 94, y: 120, c: :system)
    @stats_box.label(@character.mdef, f: font, h: 30, x: 146, y: 120, c: :warning)
    @stats_box.label(labels[12], h: 30, x: x1, y: 120, c: :system)
    @stats_box.label(@character.luck, f: font, h: 30, x: x2 + 8, y: 120, c: :warning)
  end

  def make_available_heroes
    @character_sprites = []
    viewport = Viewport.new(4, 40, @row_max == 10 ? 324 : 468, 54)
    @actors.each do |actor|
      @character_sprites << char = Sprite_KUnitDummy.new(actor, vp: viewport)
      x = 36 * ((@character_sprites.size - 1) % @row_max)
      y = 54 * ((@character_sprites.size - 1) / @row_max)
      char.xyz(4 + x, 40 + y, 10)
    end
    @character_sprites[0].active = true
    @character = @character_sprites[0].character
  end

  def make_team_background_sprites
    @back_sprites = []
    @podium_sprites = []
    @chosen_sprites = []
    @team_sprites = {}
    w = @perteam == 4 ? 44 : 40
    skyblue  = Color[:skyblue]
    @white = Color[:white].dup
    @white.alpha = 180
    @team_max.times do |n|
      @team_sprites[n] = []
      x = 4 + n % @team_cols * (@perteam * w + 12)
      y = 198 + n / @team_cols * 78
      color = n == 0 ? skyblue : @white
      @back_sprites << Sprite_Box.new(x, y, w: @perteam * 40, h: 44, z: 5, c: color)
    end
  end

  def make_team_sprites
    podium = KUnits::ICONS[2]
    w = @perteam < 5 ? 28 : 12
    (@team_max * @perteam).times do |n|
      id = n / @perteam
      x = 8 + n % (@team_cols * @perteam) * 40 + id % @team_cols * w
      y = 214 + n / (@perteam * @team_cols) * 78
      @podium_sprites << Sprite_Icon.new(x, y, podium)
      heroes = KUnits.add_heroes[id + 1]
      if heroes and heroes[n % @perteam]
        actor = @actors[heroes[n % @perteam]]
      else
        actor = Warrior.new(0)
        actor.name = "Number #{n+1}"
        actor.character_name = n % 2 == 0 ? 'ShadowBoy' : 'ShadowGirl'
      end
      @team_sprites[id] << sprite = Sprite_KUnitDummy.new(actor)
      sprite.xyz(x - 1, y - 40, 25)
      @chosen_sprites << sprite
      @test = Text.new(text: '', h: 60, x: 10, y: 380)
    end
  end

  def hold_button?(id) @@buttons[id] == @@hold_id and @@up_ticks == 0 end
  def update_animations() @character_sprites.each {|s| s.update } end
  def update_scene
    case @stage
    when 0 then update_hero_selection
    when 1 then update_team_selection
    when 2 then update_options
    when 3 then update_apply
    when 4 then update_revert
    end
  end

  def update_hero_selection
    if press_quit?
      Game.cancel_se.play
      @stage = 2
      @options.show
    elsif hold_left?
      Game.cursor_se.play(0.7) if @@up_ticks == 0
      @@up_ticks = 4
      update_previous_hero_sprite
      @index = (@index + @max - 1) % @max
      update_heroes_left
      update_current_hero_sprite
      update_hero_stats
    elsif hold_right?
      Game.cursor_se.play(0.7) if @@up_ticks == 0
      @@up_ticks = 4
      update_previous_hero_sprite
      @index = (@index + 1) % @max
      update_heroes_right
      update_current_hero_sprite
      update_hero_stats
    elsif press_enter?
      if @chosen_actors.include?(@character.id)
        Game.wrong_se.play
        return
      end
      Game.ok_se.play
      @stage = 1
      @stage_box[2] = KUnits.stage_labels[@stage]
    end
  end

  def update_heroes_left
    return if @index < @row_max
    @last_y = @index / @row_max * 54
    @character_sprites.each {|s| s.y += 54 } if (@index + 1) % @row_max == 0
    @arrow = @arrows[0] if @index < @row_max * 2 - 1
    return unless @last_index == 0 and @index > @row_max * 2 - 1
    @arrow = @arrows[1]
    new_y = 54 * ((@index / @row_max) - 1)
    @character_sprites.each {|s| s.y -= new_y }
  end

  def update_heroes_right
    return if @last_y == (new_y = @index / @row_max * 54)
    @last_y = new_y
    if @index == 0 and @last_index == @max - 1
      @arrow = @arrows[0]
      @character_sprites.each {|s| s.reset_pos }
    elsif @index > @row_max * 2 - 1
      @arrow = @arrows[1]
      @character_sprites.each {|s| s.y -= 54 }
    end
  end

  def update_previous_hero_sprite
    @last_index = @index
    @character_sprites[@index].active = nil
  end

  def update_current_hero_sprite
    @cursor.update_pos(@index)
    sprite = @character_sprites[@index]
    sprite.active = true
    @character = sprite.character
  end

  def update_hero_stats
    @stats_box[1] = @character.name
    @stats_box[3] = @character.level
    @stats_box[5] = GameData.classes[@character.class_id].name
    @stats_box[7] = @character.hp
    @stats_box[9] = @character.mp
    @stats_box[11] = @character.ap
    @stats_box[13] = @character.sp
    @stats_box[15] = @character.atk
    @stats_box[17] = @character.matk
    @stats_box[19] = @character.agil
    @stats_box[21] = @character.pdef
    @stats_box[23] = @character.mdef
    @stats_box[25] = @character.luck
    @desc_box[1] = @character.desc.empty? ? KUnits.desc_labels[1] : @character.desc
  end

  def update_team_selection
    if press_quit?
      Game.cancel_se.play(1.2)
      @stage = 0
      @stage_box[2] = KUnits.stage_labels[@stage]
    elsif press_enter?
      if @chosen_actors.include?(@character.id) or @full_teams[@team_index] == @perteam
        Game.wrong_se.play
        return
      end
      Game.ok_se.play
      update_team_data
      update_previous_hero_sprite
      @index = (@index + 1) % @max
      update_heroes_right
      update_current_hero_sprite
      update_hero_stats
      return unless @full_teams.inject(&:+) == @perteam * @team_max
      @stage = 2
      @options.show
      @ticks += 6
      return
    elsif hold_left?
      Game.cursor_se.play(0.7) if @@up_ticks == 0
      @@up_ticks = 5
      @team_index = (@team_index + @team_max - 1) % @team_max 
      skyblue  = Color[:skyblue]
      @team_max.times {|n| @back_sprites[n].color = n == @team_index ? skyblue : @white }
      @test.text = @team_index
      return
    elsif hold_right?
      Game.cursor_se.play(0.7) if @@up_ticks == 0
      @@up_ticks = 5
      @team_index = (@team_index + 1) % @team_max 
      skyblue  = Color[:skyblue]
      @team_max.times {|n| @back_sprites[n].color = n == @team_index ? skyblue : @white }
      @test.text = @team_index
    end
  end

  def update_team_data
    @chosen_actors << cid = @character.id
    n = @full_teams[@team_index] + @team_index * @perteam
    @chosen_sprites[n].change_character(@character)
    @full_teams[@team_index] += 1
    @teams[@team_index + 1] << cid
  end

  def update_options
    @options.update
    if press_quit?
      Game.cancel_se.play
      @options.index = 0
      @stage = 0
      return
    elsif press_enter?
      case @options.index
      when 0
        return Game.wrong_se.play unless @full_teams.inject(&:+) == @perteam * @team_max
        Game.ok_se.play
        @ticks = 6
        ids = @actors.map(&:id)
        Game.lost_heroes = ids - @chosen_actors
        @team_max.times do |n| n += 1
          Game.parties[n] = party = Party.new(n)
          party.setup_heroes(@teams[n])
          Players[n] = Player.new(n)
        end
        Map.load(Game.map_id)
        Players.now.xy(Game.first_x, Game.first_y)
        Game.startup_settings if Game.starting?
        Game.setup(SceneMap)
        return
      when 1
        return Game.wrong_se.play if @chosen_actors.size == 0
        Game.ok_se.play
        @options.hide
        @options.index = 0
        @revert_index = @chosen_sprites.size - 1
        @stage = 4
        @clear = true
        @stage_box[2] = KUnits.stage_labels[0]
        return
      when 2
        Game.ok_se.play
        @character_sprites.clear
        @back_sprites.clear
        @podium_sprites.clear
        @chosen_sprites.clear
        Game.starting? ? Game.setup(SceneTitle) : Game.setup(SceneMap)
      end
    end
  end
  
  def update_revert
    @chosen_sprites[@revert_index].change_character
    @revert_index -= 1
    @revert_index > -1 ? return : @clear = nil
    check_unknown_heroes
    @stage = 0
  end

  def draw
    super
    @header.draw
    @stage_box.draw
    @stats_box.draw
    @desc_box.draw
    @cursor.draw
    @character_sprites.each {|s| s.draw }
    @back_sprites.each {|s| s.draw }
    @podium_sprites.each {|s| s.draw }
    @chosen_sprites.each {|s| s.draw }
    @arrow.draw(0, 148, 15)
    @options.draw if @stage == 2
  end
end

class SceneKUnitsAchieve < SceneBase
  def setup_bgm() Game.play_list(50, KUnitsAchieve::BGM) end
  def setup(**options)
    @index = options[:i] || options[:index] || 0
    @hero = Game.party.heroes[@index]
    @max = Game.party.heroes.size
    @bg = Load.backdrop(KUnitsAchieve::BACKDROP)
    @header = Sprite_Box.new(0, 0, w: @window_width, h: 32, c: Game.outline_color)
    @header.label(KUnitsAchieve.title, y: 6, h: 38, a: :center, o: :alert)
    fn = 'arrows4'
    @arrows = [Sprite_IconTiles.new(4, 4, -4, -1, 2, fn), Sprite_IconTiles.new(772, 4, -4, -1, 3, fn)]
    @buttons = [Sprite_Icon.new(36, 4, 'L button'), Sprite_Icon.new(734, 4, 'R button')]
    color = Color[:black].dup
    color.alpha = 160
    @box = Sprite_Box.new(8, 40, w: 160, h: 184, c: color)
    level = KUnits.stats_labels[1] + ' ' + @hero.level.to_s
    white = Color[:white].dup
    @box.label(@hero.name, h: 32, x: -2, y: 112, a: :center, c: white, o: :frozen)
    @box.label(@hero.class_name, h: 32, x: -2, y: 136 , a: :center, c: white, o: :frozen)
    @box.label(level, h: 32, y: 160, a: :center, c: white, o: :frozen)
    @face_sprite = Sprite_Face.new(38, 44, 'No Face')
    @hero_sprite = Sprite_KUnitDummy.new(@hero)
    @hero_sprite.xyz(72, 68, 15)
    @hero_sprite.active = true
    @titles_label = Sprite_Box.new(8, 228, w: 228, h: 28, c: color)
    @titles_label.label(KUnitsAchieve.labels[0], y: 4, h: 32, a: :center)
    @medals_label = Sprite_Box.new(240, 228, w: 552, h: 28, c: color)
    @medals_label.label(KUnitsAchieve.labels[1], y: 4, h: 32, a: :center)
    text = KUnits.desc_labels
    desc = @hero.desc.empty? ? text[1] : @hero.desc
    @desc_box = Sprite_Box.new(8, 562, w: 784, h: 40, c: color)
    @desc_box.label(text[0], h: 29, x: 20, y: -8, o: :alert)
    @desc_box.label(desc, h: 28, x: 4, y: 16, o: :frozen)
    make_titles_medals
  end

  def make_titles_medals
    @title_max, @medal_max = 12, 10
    @titles = Sprite_Box.new(8, 260, w: 228, h: 164, c: Gosu::Color.new(0,0,0,0))
    @medal_sprites = []
    titles = @hero.titles.sort
    @title_max.times do |n|
      title = titles[n].name rescue 'This is a simple test!'
      @titles.label(title, h: 32, y: n * 24, a: :center, o: Color[:frozen])
    end
    m = @hero.medals.sort
    @medal_max.times do |n|
      x = 244 + n % @medal_max * 52
      y = 264 + n / @medal_max * 64
      name = m[n].filename rescue ''
      @medal_sprites << Sprite_Icon.new(x, y, name)
    end
  end

  def update_animations() @hero_sprite.update end
  def update_scene
    if press_quit?
      Game.cancel_se.play
      Game.last_scene
      return
    elsif hold_left? or hold_L1?
      Game.cursor_se.play(0.7) if @@up_ticks == 0
      @@up_ticks = 4
      @index = (@index + @max - 1) % @max
      update_hero
    elsif hold_right? or hold_R1?
      Game.cursor_se.play(0.7) if @@up_ticks == 0
      @@up_ticks = 4
      @index = (@index + 1) % @max
      update_hero
    end
  end

  def update_hero
    @hero = Game.party.heroes[@index]
    @box[0] = @hero.name
    @box[1] = @hero.class_name
    @box[2] = KUnits.stats_labels[1] + ' ' + @hero.level.to_s
    @desc_box[1] = @hero.desc.empty? ? KUnits.desc_labels[1] : @hero.desc
    @hero_sprite.change_character(@hero)
    titles = @hero.titles.sort
    @title_max.times {|n| @titles[n] = title = titles[n].name rescue 'This is a simple test!' }
    m = @hero.medals.sort
    @medal_max.times {|n| name = m[n].filename rescue ''
      @medal_sprites[n].change(name) }
  end

  def draw
    super
    @header.draw
    @arrows.each {|arrow| arrow.draw }
    @buttons.each {|button| button.draw }
    @box.draw
    @face_sprite.draw
    @hero_sprite.draw
    @titles_label.draw
    @medals_label.draw
    @desc_box.draw
    @titles.draw
    @medal_sprites.each {|medal| medal.draw }
  end
end

class SceneKUnitsFoes < SceneBase
  def setup_bgm() Game.play_list(60, KUnitsFoes::BGM) end
  def setup(**options)
    @index = options[:i] || options[:index] || 0
    @page_index = @alert_index = 0
    @alert_ticks = 40
    @kinds = []
    @color_indexes = []
    @foes = Game.monsters.map {|mid| GameData.foes[mid] } rescue []
    @foes = GameData.foes[1..-1].dup if @foes.empty?
    @foes.each do |foe|
      KUnitsFoes::MONSTERS.each do |s,ids|
        next unless ids.include?(foe.id)
        @kinds << s
        @color_indexes << KUnitsFoes::DARK_BD.include?(s)? 1 : 0
        break
      end
    end
    @group_max = @foes.size
    @font = 'Footlight MT Light'
    @tales = KUnitsFoes.tales.dup
    @tips = KUnitsFoes.tips.dup
    @foe = @foes[@index]
    @back_name = @group_max > 1 ? KUnitsFoes.backdrop(@kinds[@index]) : 'peaceful sunset'
    @last_backdrop_name = @back_name
    @bg = Load.backdrop(@back_name)
    @header = Sprite_Box.new(0, 0, w: @window_width, h: 32, c: Game.outline_color)
    @header.label(KUnitsFoes.title, y: 6, h: 38, a: :center, o: :alert)
    @monster_battler = Sprite_Battler.new(0, 180, @foe.battler_name, scale: :small)
    @monster_sprite = Sprite_KUnitDummy.new(@foe)
    @monster_sprite.xyz(20, @window_height - 140, 15)
    @monster_sprite.active = true
    setup_labels
  end

  def setup_labels
    color = Color[:black].dup
    color.alpha = 120
    @monster_label = Sprite_Box.new(4, @window_height - 32, w: 470, h: 28, c: color)
    @monster_label.label("#{@index + 1}/#{@group_max}", f: @font, h: 32, x: 4, y: 4, o: :frozen)
    @monster_label.label(@foes[@index].name, h: 32, a: :center, y: 4, o: :frozen)
    @x = 480
    w, h  = @window_width - @x, @window_height - 44
    @data_frame = Sprite_Box.new(@x, 40, w: w, h: h, c: color, z: 20)
    @labels = KUnits.stats_labels
    @foes_labels = KUnitsFoes.labels
    draw_data_frame
    @data_frame.label(Game.party.wins[@foe.id], f: @font, h: 30, x: 100, y: 231, o: :alert)
    @data_frame.label(@foe.money, f: @font, h: 30, x: 100, y: 255, o: :alert)
    tales = @tales[@foe.id]
    tips = @tips[@foe.id]
    @tale_frame = Sprite_Box.new(@x, 40, w: w, h: h, c: :void, z: 25)
    label = sprintf(@foes_labels[3], @foe.name)
    @tale_frame.label(label, h: 34, a: :center, y: 48, o: :alert)
    @tale_frame[0].opacity = 0
    10.times {|n| @tale_frame.label(tales[n], h: 30, x: 6, y: 86 + 24 * n, c: :white, o: :frozen)
                  @tale_frame[n+1].opacity = 0 }
    @tips_frame = Sprite_Box.new(@x, 40, w: w, h: h, c: :void, z: 25)
    label = sprintf(@foes_labels[4], @foe.name)
    @tips_frame.label(label, h: 34, a: :center, y: 48, o: :alert)
    @tips_frame[0].opacity = 0
    10.times {|n| @tips_frame.label(tips[n], h: 30, x: 6, y: 86 + 24 * n, c: :white, o: :frozen)
                  @tips_frame[n+1].opacity = 0 }
    @labels = nil
    make_ticker
  end
  
  def draw_data_frame
    @data_frame.label(@foes_labels[0], h: 34, a: :center, y: 48, o: :alert)
    @data_frame.label(@labels[1], h: 30, x: 6, y: 86, o: :frozen)
    @data_frame.label(@labels[3], h: 30, x: 164, y: 86, o: :frozen)
    @data_frame.label(@labels[4], h: 30, x: 6, y: 110, o: :frozen)
    @data_frame.label(@labels[5], h: 30, x: 164, y: 110, o: :frozen)
    @data_frame.label(@labels[6], h: 30, x: 6, y: 134, o: :frozen)
    @data_frame.label(@labels[7], h: 30, x: 164, y: 134, o: :frozen)
    @data_frame.label(@labels[8], h: 30, x: 6, y: 158, o: :frozen)
    @data_frame.label(@labels[9], h: 30, x: 164, y: 158, o: :frozen)
    @data_frame.label(@labels[10], h: 30, x: 6, y: 182, o: :frozen)
    @data_frame.label(@labels[11], h: 30, x: 164, y: 182, o: :frozen)
    @data_frame.label(@labels[12], h: 30, x: 6, y: 206, o: :frozen)
    @data_frame.label(@labels[13], h: 30, x: 164, y: 206, o: :frozen)
    @data_frame.label(@foes_labels[1], h: 30, x: 6, y: 230, o: :frozen)
    @data_frame.label(@foes_labels[2], h: 30, x: 6, y: 254, o: :frozen)
    @data_frame.label(@foe.level, f: @font, h: 30, x: 85, y: 87, o: :alert)
    @data_frame.label(@foe.hp, f: @font, h: 30, x: 230, y: 87, o: :alert)
    @data_frame.label(@foe.mp, f: @font, h: 30, x: 85, y: 111, o: :alert)
    @data_frame.label(@foe.ap, f: @font, h: 30, x: 230, y: 111, o: :alert)
    @data_frame.label(@foe.sp, f: @font, h: 30, x: 85, y: 135, o: :alert)
    @data_frame.label(@foe.atk, f: @font, h: 30, x: 230, y: 135, o: :alert)
    @data_frame.label(@foe.matk, f: @font, h: 30, x: 85, y: 159, o: :alert)
    @data_frame.label(@foe.pdef, f: @font, h: 30, x: 230, y: 159, o: :alert)
    @data_frame.label(@foe.mdef, f: @font, h: 30, x: 85, y: 183, o: :alert)
    @data_frame.label(@foe.agil, f: @font, h: 30, x: 230, y: 183, o: :alert)
    @data_frame.label(@foe.luck, f: @font, h: 30, x: 85, y: 207, o: :alert)
    @data_frame.label(@foe.block, f: @font, h: 30, x: 230, y: 207, o: :alert)
  end

  def make_ticker
    @alerts = KUnitsFoes.alerts
    color = Color[:skyblue]
    color.alpha = 120
    @ticker = Sprite_Box.new(@x, 380, w: @window_width - @x, h: 28, z: 25, c: color)
    @ticker.label(@alerts[@alert_index], h: 32, y: 4, a: :center, o: :frozen)
  end

  def update_animations
    if @alert_ticks == 0
      @alert_index = (@alert_index + 1) % @alerts.size
      @ticker[0] = @alerts[@alert_index]
      @alert_ticks = 40
    end
    @alert_ticks -= 1 if @alert_ticks > 0
    @monster_sprite.update
    method(@execute).call if @execute
  end

  def update_scene
    if press_quit?
      Game.cancel_se.play
      Game.last_scene
      return
    elsif press_up?
      Game.cursor_se.play
      @index = (@index + @group_max - 1) % @group_max
      @execute = :update_battler_leaving
      return
    elsif press_down?
      Game.cursor_se.play
      @index = (@index + 1) % @group_max
      @execute = :update_battler_leaving
      return
    elsif press_left?
      Game.cursor_se.play
      @ticks = 16
      @page_index = (@page_index + 2) % 3
      @execute = :update_last_page_opacity
      if @page_index == 0
        @last_page = @tale_frame
        @new_page = @data_frame
      elsif @page_index == 1
        @last_page = @tips_frame
        @new_page = @tale_frame
      else
        @last_page = @data_frame
        @new_page = @tips_frame
      end
      return
    elsif press_right?
      Game.cursor_se.play
      @ticks = 16
      @page_index = (@page_index + 1) % 3
      @execute = :update_last_page_opacity
      if @page_index == 0
        @last_page = @tips_frame
        @new_page = @data_frame
      elsif @page_index == 1
        @last_page = @data_frame
        @new_page = @tale_frame
      else
        @last_page = @tale_frame
        @new_page = @tips_frame
      end
    end
  end

  def update_battler_leaving
    @monster_battler.x -= 80 if @monster_battler.x > -640
    @execute = :update_foe_battler if @monster_battler.x == -640
  end
  
  def update_foe_battler
    @foe = @foes[@index]
    @monster_label[0] = "#{@index + 1}/#{@group_max}"
    @monster_label[1] = @foe.name
    @monster_battler.change(@foe.battler_name)
    @monster_sprite.change_character(@foe)
    @back_name = @group_max > 1 ? KUnitsFoes.backdrop(@kinds[@index]) : 'peaceful sunset'
    unless @last_backdrop_name == @back_name
      @last_backdrop_name = @back_name
      @bg = Load.backdrop(@back_name)
    end
    @execute = :update_foe_data
  end
  
  def update_foe_data
    @data_frame[15] = @foe.level
    @data_frame[16] = @foe.hp
    @data_frame[17] = @foe.mp
    @data_frame[18] = @foe.ap
    @data_frame[19] = @foe.sp
    @data_frame[20] = @foe.atk
    @data_frame[21] = @foe.matk
    @data_frame[22] = @foe.pdef
    @data_frame[23] = @foe.mdef
    @data_frame[24] = @foe.agil
    @data_frame[25] = @foe.luck
    @data_frame[26] = @foe.block
    @data_frame[27] = Game.party.wins[@foe.id]
    @data_frame[28] = @foe.money
    tales = @tales[@foe.id]
    tips = @tips[@foe.id]
    @tale_frame[0] = sprintf(@foes_labels[3], @foe.name)
    @tips_frame[0] = sprintf(@foes_labels[4], @foe.name)
    1.upto(10) do |n|
      @tale_frame[n] = tales[n-1]
      @tips_frame[n] = tips[n-1]
    end
    @execute = :update_battler_arrival
  end

  def update_battler_arrival
    @monster_battler.x += 160 if @monster_battler.x < 0
    @execute = nil if @monster_battler.x == 0
  end

  def update_last_page_opacity
    @last_page.opacity -= 32
    @execute = :update_new_page_opacity if @last_page.opacity == 0
  end
  
  def update_new_page_opacity
    @new_page.opacity += 32
    @last_page = @new_page = @execute = nil if @new_page.opacity == 255
  end

  def draw
    super
    @header.draw
    @ticker.draw
    @monster_sprite.draw
    @monster_label.draw
    @data_frame.draw
    @tale_frame.draw
    @tips_frame.draw
    @monster_battler.draw
  end
end

class SceneKUnitsBank < SceneBase
  def setup_bgm() Game.play_list(50, KUnitsBank::BGM) end
  def setup(id:)
    @index = @stage = 0
    @id = id
    @pin = ''
    @bg = Load.backdrop(KUnitsBank::BACKDROP)
    black = Color[:black].dup
    black.alpha = 160
    @header = Sprite_Box.new(0, 0, w: @window_width, h: 32, c: black)
    bank_name = KUnitsBank::BANK_NAMES[@id]
    branch_name = KUnitsBank::BRANCH_NAMES[Map.id]
    branch_label = sprintf(KUnitsBank.branch_label, branch_name)
    name = bank_name + ' ' + branch_label if [:ENG, :ESP].include?(KUnits.lang)
    @header.label(name, y: 6, h: 38, a: :center, o: :alert)
    any_deposit = Game.party.bank_money[id] != nil
    opt = KUnitsBank.options(any_deposit)
    @options = CommandSpriteset.new(280, 300, 240, opt)
    @account_options = CommandSpriteset.new(280, 300, 240, KUnitsBank.account_options)
    @account_options.hide
    @warning_box = Sprite_Box.new(250, 52, w: 300, h: 28, c: black)
    @warning_box.label(' ', a: :center, y: 4, h: 31, o: :frozen)
    @warning_box.visible = nil
    @amount_box = Sprite_Box.new(291, 92, pic: KUnitsBank::INPUT_BOXES[0])
    @amount_box.label(' ', f: 'Footlight MT Light', a: :right, x: -14, y: 16, h: 45, o: :frozen)
    @amount_box.visible = nil
    @values = ['1','2','3','4','5','6','7','8','9','00','0','']
    @buttons = []
    sprites = KUnitsBank::NUMBER_SPRITES
    13.times {|n| x = 316 + n % 3 * 56
                  y = 160 + n / 3 * 56
                  @buttons << button = Sprite_IconTiles.new(x, y, 56, 56, 0, sprites[n])
                  button.visible = nil }
    @buttons[0].activate
    @buttons[12].x = 376
    picture, x, w = KUnitsBank::INPUT_BOXES[1], [291,317], [29,160,29]#,477
    @progress_bar = Sprite_CompositePicture.new(picture, x: x, y: 101, w: w, h: 37)
    @progress_bar.visible = nil
  end

  def update_animations
    return unless @show_progress
    @progress_bar.increase_width = 10
    @show_progress = nil if @progress_bar.progress == 160
  end

  def update_scene
    return method(@next_method).call if @next_method
    case @stage
    when 0 then update_main
    when 1 then update_pin
    when 2 then update_account
    when 3 then update_kind
    when 4 then update_deposit
    when 5 then update_check_deposit
    when 6 then update_item_deposit
    when 7 then update_withdraw
    when 8 then update_item_withdraw
    when 9 then update_choose_account
    when 10 then update_transfer
    when 11 then update_item_transfer
    when 12 then update_item_transfer_approval
    end
  end

  def update_main
    @options.update
    if press_quit?
      Game.cancel_se.play
      Players.now.halt = nil
      Game.last_scene
      return
    elsif press_enter?
      Game.ok_se.play
      if @options.index == 2
        Game.ok_se.play
        Game.last_scene
        return
      end
      @options.hide
      if @pin.size == 4
        @account_options.show
        @stage = 2
        return
      end
      @buttons.each {|b| b.visible = true } rescue nil
      @warning_box[0] = KUnitsBank.pin_labels[0]
      @amount_box[0] = ''
      @warning_box.visible = true
      @amount_box.visible = true
      @mode = Game.party.bank_pins[@id] ? :single : :twice
      @stage = 1
      return
    end
  end

  def update_pin
    if press_quit?
      Game.cancel_se.play
      @buttons.each {|b| b.visible = nil }
      @options.show
      @stage = 0
      return
    elsif press_enter?
      return Game.wrong_se.play if [9,11].include?(@index)
      return Game.wrong_se.play if @index == 12 and @pin.size < 4
      return Game.wrong_se.play if @index < 12 and @pin.size == 4
      if @index < 12
        Game.ok_se.play
        @pin += @values[@index]
        @amount_box[0] = '* ' * @pin.size
      else
        if @mode == :twice and !@temp_pin
          Game.ok_se.play
          @temp_pin = @pin.dup
          @amount_box[0] = @pin = ''
          @warning_box[0] = KUnitsBank.pin_labels[1]
          return
        end
        if (@mode == :twice and @pin != @temp_pin) or (@mode == :single and Game.party.bank_pins[@id] != @pin)
          Game.wrong_se.play
          @amount_box[0] = @pin = ''
          @warning_box[0] = KUnitsBank.pin_labels[3]
          return
        end
        Game.ok_se.play
        if @mode == :twice
          Game.party.bank_pins[@id] = @pin
          Game.party.make_bank_account(@id)
          @options.refresh_commands(KUnitsBank.options(true))
          Game.save_data
        end
        @warning_box[0] = KUnitsBank.pin_labels[2]
        @ticks = 18
        @progress_bar.visible = @show_progress = true
        @amount_box[0] = ''
        @next_method = :process_pin
      end
      return
    elsif hold_left?
      Game.cursor_se.play(0.7) if @@up_ticks == 0
      @@up_ticks = 4
      @buttons[@index].deactivate
      @index = (@index + 12) % 13
      @buttons[@index].activate
      return
    elsif hold_right?
      Game.cursor_se.play(0.7) if @@up_ticks == 0
      @@up_ticks = 4
      @buttons[@index].deactivate
      @index = (@index + 1) % 13
      @buttons[@index].activate
    end
  end

  def process_pin
    @progress_bar.visible = nil
    @warning_box.visible = nil
    @amount_box.visible = nil
    @buttons.each {|b| b.visible = nil }
    @warning_box[0] = KUnitsBank.pin_labels[2]
    @amount_box[0] = 0
    @account_options.show
    @next_method = nil
    @stage = 2
  end

  def update_account
    @account_options.update
    if press_quit?
      Game.cancel_se.play
      back2main
      return
    elsif press_enter?
      Game.ok_se.play
      return back2main if @account_options.index == 3
    end
  end

  def back2main
    @account_options.hide
    @account_options.index = 0
    @options.show
    @stage = 0
  end

  def update_kind
    
  end

  def update_deposit
    
  end

  def update_check_deposit
    
  end

  def update_item_deposit
    
  end

  def update_withdraw
    
  end

  def update_item_withdraw
    
  end

  def update_choose_account
    
  end

  def update_transfer
    
  end

  def update_item_transfer
    
  end

  def update_item_transfer_approval
    
  end

  def draw
    super
    @header.draw
    @options.draw
    @account_options.draw
    @warning_box.draw
    @amount_box.draw
    @progress_bar.draw
    @buttons.each {|b| b.draw }
  end
end

class SceneKUnitsShop < SceneBase
  def setup_bgm() Game.play_list(60, KUnitsShop::BGM) end
  def setup(kind:, goods: {}, orders: {}, commissions: {}, sell: {}, id:)
    @party = Game.party
    @stage = @index = 0
    @kind = kind rescue @kind = :rich
    @goods = {}
    @set = {}
    @orders = orders
    @commissions = commissions
    @sell_percent = sell
    @visible = true
    @bg_color = Color[@kind != :normal ? :black : :gray].dup
    @bg_color.alpha = 160
    @max = { items: goods[:items].size, weapons: goods[:weapons].size,
             accessories: goods[:accessories].size, skills: goods[:skills].size }
    @kinds = []
    purchase_options = [KUnitsShop.buy_labels[0].dup]
    if !goods[:items].empty?
      @goods[:items] = goods[:items].map{|n| GameData.items[n].dup }
      purchase_options << KUnitsShop.buy_labels[1].dup
      @kinds << :items
      @set[:items] = ShopItemSpriteset.new(@bg_color)
    end
    if !goods[:weapons].empty?
      @goods[:weapons] = goods[:weapons].map{|n| GameData.weapons[n].dup }
      purchase_options << KUnitsShop.buy_labels[2].dup
      @kinds << :weapons
      @set[:weapons] = ShopWeaponSpriteset.new(@bg_color)
    end
    if !goods[:armors].empty?
      @goods[:armors] = goods[:armors].map{|n| GameData.armors[n].dup }
      purchase_options << KUnitsShop.buy_labels[3].dup
      @kinds << :armors
      @set[:armors] = ShopArmorSpriteset.new(@bg_color)
    end
    if !goods[:accessories].empty?
      @goods[:accessories] = goods[:accessories].map{|n| GameData.accessories[n].dup }
      purchase_options << KUnitsShop.buy_labels[4].dup
      @kinds << :accessories
      @set[:accessories] = ShopAccessorySpriteset.new(@bg_color)
    end
    if !goods[:skills].empty?
      @goods[:skills] = goods[:skills].map{|n| GameData.skills[n].dup }
      purchase_options << KUnitsShop.buy_labels[5].dup
      @kinds << :skills
      @set[:skills] = ShopSkillSpriteset.new(@bg_color)
    end
    @goods.freeze
    @purchase_options_max = purchase_options.size
    @goods_kind = @kinds.shift if @kinds.size == 1
    @bg = Load.backdrop(KUnitsShop::BACKDROPS[@kind])
    title = sprintf(KUnitsShop.title, Map.event.name)
    @header = Sprite_Box.new(0, 0, h: 32, c: @bg_color)
    @header.label(title, y: 6, h: 34, a: :center, o: :alert)
    fn = 'arrows4'
    @arrows = [Sprite_IconTiles.new(8, 96, -4, -1, 2, fn), Sprite_IconTiles.new(204, 96, -4, -1, 3, fn)]
    @icon_sprite = Sprite_Icon.new(80, 68, '')
    options = KUnitsShop.labels
    @option_menu = CommandSpriteset.new(@window_width / 2 - 110, 340, 220, options)
    @purchase_menu = CommandSpriteset.new(@window_width / 2 - 110, 340, 220, purchase_options)
    @purchase_menu.hide
    setup_labels
    toggle_label_visibility
  end

  def setup_labels
    amount_font = 'Oxygen Mono'#'Noto Sans Regular'#'Footlight MT Light'
    currency = Game.terms(:money)
    @gold_box = Sprite_Box.new(4, 36, h: 26, w: 220, c: @bg_color)
    @gold_box.label(@party.money, f: amount_font, h: 31, a: :right, x: -20, y: 4, o: :frozen)
    @gold_box.label(currency, h: 31, f: amount_font, a: :right, x: -4, y: 4, o: :darkgreen)
    @index_sprite = Text.new(text: '_', f: amount_font, h: 24, x: 8, y: 122, o: :frozen)
    @name_box = Sprite_Box.new(8, 140, w: 220, h: 26, c: @bg_color)
    @name_box.label('_', h: 29, a: :center, y: 5, o: :frozen)
    @price_box = Sprite_Box.new(8, 170, w: 220, h: 26, c: @bg_color)
    @price_box.label(Game.terms(:price), h: 32, x: 4, y: 4, o: :darkgreen)
    @price_box.label(0, f: amount_font, h: 31, a: :right, x: -20, y: 4, o: :frozen)
    @price_box.label(currency, f: amount_font, h: 30, a: :right, x: -4, y: 4, o: :darkgreen)
    @amount_box = Sprite_Box.new(248, 200, h: 78, w: 220, c: @bg_color)
    @amount_box.label(Game.terms(:number), h: 30, x: 4, y: 4, o: :darkgreen)
    @amount_box.label(1, f: amount_font, h: 30, a: :right, x: -1, y: 4, o: :alert)
    @amount_box.label(Game.terms(:amount), h: 30, x: 4, y: 30, o: :darkgreen)
    @amount_box.label(0, f: amount_font, h: 30, a: :right, x: -20, y: 30, o: :frozen)
    @amount_box.label(currency, f: amount_font, h: 31, a: :right, x: -4, y: 30, o: :darkgreen)
    @amount_box.visible = nil
  end

  def toggle_label_visibility
    @visible = !@visible
    @arrows.each {|arrow| arrow.visible = @visible }
    @icon_sprite.visible = @visible
    @index_sprite.visible = @visible
    @name_box.visible = @visible
    @price_box.visible = @visible
    @spriteset.visible = @visible if @spriteset
  end

  def refresh_current_item
    @item = @stuff[@index]
    name = @item.icon
    name += '_large' if File.exist?('images/icons/' + name + '_large.png')
    @icon_sprite.change(name)
    @index_sprite.text = "#{@index+1}/#{@max[@goods_kind]}"
    @name_box[0]  = @item.name
    @price_box[1] = local_price
    @spriteset.update_item(@item)
  end
  def local_price() @item.price + (@item.price * Map.price_increase).round end

  def update_scene
    case @stage
    when 0 then update_main_menu
    when 1 then update_purchase_menu
    when 2 then update_choose_item
    when 3 then update_purchase_item
    when 4 then update_order
    when 5 then update_pickup
    end
  end

  def update_main_menu
    @option_menu.update
    if press_quit?
      Game.cancel_se.play
      Map.event.deactivate
      Game.last_scene
      return
    elsif press_enter?
      @option_menu.hide# if @stage > 0
      case @option_menu.index
      when 0
        Game.ok_se.play
        if @purchase_options_max > 2
          @stage = 1
          @purchase_menu.show
        else
          @stage = 2
          @stuff = @goods[@goods_kind]
          @spriteset = @set[@goods_kind]
          refresh_current_item
          toggle_label_visibility
        end
      end
    end
  end

  def update_purchase_menu
    @purchase_menu.update
    if press_quit?
      Game.cancel_se.play
      @stage = 0
      @purchase_menu.hide
      @option_menu.show
      return
    elsif press_enter?
      Game.ok_se.play
      @stage = 2
      @purchase_menu.hide
      @goods_kind = @kinds[@purchase_menu.index]
      @stuff = @goods[@goods_kind]
      @spriteset = @set[@goods_kind]
      refresh_current_item
      toggle_label_visibility
    end
  end

  def update_choose_item
    if press_quit?
      Game.cancel_se.play
      @index = 0
      toggle_label_visibility
      if @purchase_options_max > 2
        @stage = 1
        @purchase_menu.show
      else
        @stage = 0
        @option_menu.show
      end
      return
    elsif press_enter?
      return Game.wrong_se.play if @party.money < @item.price
      Game.ok_se.play
      @stage = 3
      @number = 1
      @item_max = @party.money / local_price
      @amount_box[1] = @number
      @amount_box[3] = local_price
      @amount_box.visible = true
      return
    elsif hold_left?
      Game.cursor_se.play(0.7) if @@up_ticks == 0
      @@up_ticks = 3
      @index = (@index + @max[@goods_kind] - 1) % @max[@goods_kind]
      refresh_current_item
      return
    elsif hold_right?
      Game.cursor_se.play(0.7) if @@up_ticks == 0
      @@up_ticks = 3
      @index = (@index + 1) % @max[@goods_kind]
      refresh_current_item
    end
  end

  def update_purchase_item
    if press_quit?
      Game.cancel_se.play
      @amount_box.visible = nil
      @stage = 2
      return
    elsif press_enter?
      amount = local_price * @number
      return Game.wrong_se.play(0.7) if @party.money < amount
      Game.coins_se.play
      @party.money -= amount
      @number.times { @party.items << GameData.items[@item.id] }
      @gold_box[0] = @party.money
      return
    elsif hold_up?
      if @number == @item_max
        Game.wrong_se(0.7) if @@up_ticks == 0
        @@up_ticks = 3
        return
      end
      @number = [@number - 10, 0].max
      update_number_data
      return
    elsif hold_down?
      if @number == @item_max
        Game.wrong_se(0.7) if @@up_ticks == 0
        @@up_ticks = 3
        return
      end
      @number = [@number + 10, @item_max].min
      update_number_data
      return
    elsif hold_left?
      if @number == @item_max
        Game.wrong_se(0.7) if @@up_ticks == 0
        @@up_ticks = 3
        return
      end
      @number = [@number - 1, 0].max
      update_number_data
      return
    elsif hold_right?
      if @number == @item_max
        Game.wrong_se(0.7) if @@up_ticks == 0
        @@up_ticks = 3
        return
      end
      @number = [@number + 1, @item_max].min
      update_number_data
    end
  end

  def update_number_data
    Game.cursor_se.play(0.7) if @@up_ticks == 0
    @@up_ticks = 3
    @amount_box[1] = @number
    @amount_box[3] = local_price * @number
  end

  def draw
    super
    @header.draw
    @arrows.each {|arrow| arrow.draw }
    @gold_box.draw
    @option_menu.draw
    @purchase_menu.draw
    return unless @spriteset
    @icon_sprite.draw
    @index_sprite.draw_outline
    @name_box.draw
    @price_box.draw
    @amount_box.draw
    @spriteset.draw
  end

  def clean_up
    @goods.clear
    @goods = nil
  end
end

class SceneKUnitsMenu < SceneBase
  def setup_bgm() Game.play_list(60, KUnitsMenu::BGM) end
  def setup(**options)
    @hero_index = @index = 0
    options = KUnitsMenu::OPTIONS
    color = Color[:orange].dup# color.alpha = 120
    @map_box = Sprite_Box.new(0, 0, h: 36, pic: 'wooden sign', z: 2)
    @map_box.label(KUnitsMenu.labels[0], h: 30, a: :center, y: 16, o: :alert)
    @map_box.label(Map.name, h: 36, a: :center, y: 42, o: :brown)
    @map_box.label(Map.region, h: 28, a: :center, y: 72, o: :brown)
    blue = Color[:frozen].dup
    blue.alpha = 120
    font = 'Footlight MT Light'
    @hero_max = Game.party.heroes.size
    hero = Game.party.heroes[0]
    @hero_sprite = Sprite_KUnitDummy.new(hero)
    @hero_sprite.xyz(24, 128, 5)
    @hero_sprite.active = true
    @hero_box = Sprite_Box.new(80, 108, w: 400, h: 78, c: blue)
    @hero_box.label(hero.name, h: 31, x: 4, y: 4, o: :alert, c: :warning)
    @hero_box.label(Game.terms(:lvl), h: 31, x: 132, y: 4)
    @hero_box.label(hero.level, f: font, h: 31, x: 184, y: 4, o: :darkgreen)
    @hero_box.label(hero.class_name, h: 31, x: 4, y: 30)
    @hero_box.label(Game.terms(:lvl), h: 31, x: 132, y: 30)
    @hero_box.label(hero.class_level, f: font, h: 31, x: 184, y: 30, o: :darkgreen)
    @timer = Sprite_Box.new(0, 560, h: 48, w: 160, c: blue)
    @timer.label(Game.terms(:time), x: 16, y: -8, h: 31, o: :alert)
    time = Game.timer
    time = sprintf("%02d:%02d:%02d", time/3600%24,time/60,Game.timer%60)
    @timer.label(time, f: font, a: :right, x: -8, y: 24, h: 31, o: :darkgreen)
  end

  def update_hero
    hero = Game.party.heroes[@hero_index]
    @hero_sprite.change_character(hero)
    @hero_box[0] = hero.name
    @hero_box[2] = hero.level
    @hero_box[3] = hero.class_name
    @hero_box[5] = hero.class_level
  end

  def update_animations
    @hero_sprite.update
    time = Game.timer
    @timer[1] = sprintf("%02d:%02d:%02d", time/3600%24,time/60,time%60)
  end

  def update_scene
    if press_quit?
      Game.cancel_se.play
      Game.last_scene
      return
    elsif press_enter?
      Game.ok_se.play
      Game.setup(SceneKUnitsSave, mode: :save)
      return
    elsif hold_left?
      Game.cursor_se.play
      @@up_ticks = 3
      @hero_index = (@hero_index + @hero_max - 1) % @hero_max
      update_hero
      return
    elsif hold_right?
      Game.cursor_se.play
      @@up_ticks = 3
      @hero_index = (@hero_index + 1) % @hero_max
      update_hero
    end
  end

  def draw
    @map_box.draw
    @hero_sprite.draw
    @hero_box.draw
    @timer.draw
  end
end

class SceneKUnitsSave < SceneBase
  def setup_bgm() Game.play_list(60, KUnitsSave::BGM) end
  def initialize
    super
    @stage = 0
    timestamps = []
    @files_found = []
    Dir['saves/game*.rbg'].sort.each {|file| timestamps << File.mtime(file)
      @files_found << file.scan(/\d+/)[0].to_i - 1 }
    @index = @files_found.empty? ? 0 : @files_found[timestamps.index(timestamps.max)]
    black = Color[:black].dup
    black.alpha = 160
    @bg = Load.backdrop(KUnitsSave::BACKDROP)
    @header = Sprite_Box.new(0, 0, h: 36, c: black)
    @header.label(KUnitsSave.title, y: 8, h: 34, a: :center, o: :alert)
    font = 'Footlight MT Light'
    @save_files = []
    @icons = KUnitsSave::FILE_ICONS
    17.times do |n|
      pos = @files_found.include?(n) ? 0 : 1
      @save_files << box = Sprite_Box.new(8, 38 + n * 32, pic: @icons[pos], z: 1)
      box.label("#{n + 1}", h: 34, f: font, a: :right, x: -6, y: 6)
    end
    @map_box = Sprite_Box.new(84, 36, h: 36, pic: 'wooden sign', z: 2)
    @map_box.label(KUnitsMenu.labels[0], h: 30, a: :center, y: 16, o: :alert)
    @map_box.label(' ', h: 36, a: :center, y: 42, o: :brown)
    @map_box.label(' ', h: 28, a: :center, y: 72, o: :brown)
    @map_box.visible = nil
    @party_box = Sprite_Box.new(84, 138, w: 320, h: 32, c: black)
    @party_box.label(' ', h: 31, x: 4, y: 6, o: :frozen)
    @party_box.visible = nil
    font = 'Footlight MT Light'
    @data_box = Sprite_Box.new(340, 44, w: 300, h: 84, c: black)
    @data_box.label(KUnitsSave.extra_labels[0], h: 31, x: 4, y: 6, o: :frozen)
    @data_box.label(KUnitsSave.extra_labels[1], h: 31, x: 4, y: 32, o: :frozen)
    @data_box.label(nil, f: font, h: 31, a: :right, x: -4, y: 6, o: :alert)
    @data_box.label(nil, f: font, h: 31, a: :right, x: -4, y: 32, o: :alert)
    @data_box.label(Game.terms(:time), h: 31, x: 4, y: 58, o: :frozen)
    @data_box.label(' ', f: font, h: 31, a: :right, x: -4, y: 60, o: :frozen)
    @data_box.visible = nil
    @time_box = Sprite_Box.new(84, 234, w: 260, h: 32, c: black)
    @time_box.visible = nil
    @ready_box = Sprite_Box.new(84, 272, w: 500, h: 28, c: black)
    @ready_box.label(' ', h: 31, a: :center, o: :frozen)
    @ready_box.visible = nil
    @heroes = []
    10.times {|n| @heroes << Sprite_KUnitDummy.new(nil, x: 84 + n * 32, y: 178) }
  end

  def setup(mode:)
    @mode = mode
    pos = mode == :load ? 0 : 1
    @cursor = Sprite_Icon.new(12, 38 + @index * 32, KUnitsSave::INDEX_ICONS[pos])
  end
  
  def update_scene
    case @stage
    when 0 then update_basic
    when 1 then update_selection
    when 2 then Game.setup(SceneMap) if @ticks == 0
    end
  end

  def update_basic
    if press_quit?
      Game.cancel_se.play
      Game.last_scene(index: 1)
      return
    elsif press_enter?
      return Game.wrong_se.play unless @mode == :save or @files_found.include?(@index)
      Game.ok_se.play
      @stage = 1
      load_stored_data
      @party_box.visible = true
      @data_box.visible = true
      @time_box.visible = true
      @map_box.visible = true
      return
    elsif hold_up?
      Game.cursor_se.play(0.7) if @@up_ticks == 0
      @@up_ticks = 3
      @index = (@index + 16) % 17
      @cursor.y = 38 + @index * 32 - 2
      return
    elsif hold_down?
      Game.cursor_se.play(0.7) if @@up_ticks == 0
      @@up_ticks = 3
      @index = (@index + 1) % 17
      @cursor.y = 38 + @index * 32 - 2
    end
  end

  def update_selection
    if press_quit?
      Game.cancel_se.play
      @stage = 0
      @party_box.visible = nil
      @data_box.visible = nil
      @time_box.visible = nil
      @map_box.visible = nil
      @ready_box.visible = nil
      10.times {|n| @heroes[n].change_character(nil) }
      return
    elsif press_enter?
      Game.save_index = @index
      @ticks = 6
      if @mode == :save
        Game.ok_se.play
        Game.save_data
        unless @files_found.include?(@index)
          @files_found << @index
          @save_files[@index].change_backdrop(@icons[0])
        else
          load_stored_data
        end
        @ready_box[0] = KUnitsSave.ready_labels[0]
        @ready_box.visible = true
        return
      else
        return Game.wrong_se.play unless @files_found.include?(@index)
        Game.ok_se.play
        @ready_box[0] = KUnitsSave.ready_labels[1]
        @ready_box.visible = true
        @ticks = 10
        @stage = 2
        Game.load_data
      end
    end
  end

  def load_stored_data
    data = Game.temp_load(@index)
    settings = data[:settings]
    heroes = data[:parties][settings.player_id].heroes
    max = heroes.size
    max.times {|n| @heroes[n].change_character(heroes[n]) }
    @party_box[0] = sprintf(KUnitsSave.party_label, heroes[0].name, data[:parties].size)
    map = sprintf("maps/map%03d.rbg", settings.map_id)
    File.open(map,'rb'){|f| map = Marshal.load(f) }
    @map_box[1] = map.name
    @map_box[2] = map.region
    @data_box[2] = data[:monsters]
    @data_box[3] = data[:chests]
    time = data[:time][0]
    time = sprintf("%02d:%02d:%02d", time/3600%24,time/60,time%60)
    @data_box[5] = time
  end

  def draw
    super
    @header.draw
    @save_files.each {|s| s.draw }
    @cursor.draw
    @party_box.draw
    @data_box.draw
    @time_box.draw
    @map_box.draw
    @ready_box.draw
    @heroes.each {|s| s.draw }
  end
end

class SceneKChest < SceneBase
  def kind() :kchest end
  def initialize
    super
    @alert_ticks = 40
    @left_index = @right_index = @alert_index = 0
    @side = :left
    @left_max = KChests::ITEMMAX
    @alerts = KChests.alerts
    @items = []
    @belongings = []
    @w, @h = 384, 518
  end

  def setup(id:)
    Game.play_list(60, KChests::BGM)
    @id = id
    @spriteset = MapSpriteset.new
    @ribbons = [left = Sprite_Box.new(40, 0, h: 34, pic: 'skyblue ribbon', z: 1000)]
    @ribbons << right = Sprite_Box.new(440, 0, h: 34, pic: 'skyblue ribbon', z: 1000)
    @ribbons << @ticker = Sprite_Box.new(15, @window_height - 32, pic: 'active main tab', z: 1000)
    @ribbons << lower_right = Sprite_Box.new(415, @window_height - 32, pic: 'active main tab', z: 1000)
    left.label(KChests.chest_label, h: 34, y: 12, a: :center, o: :alert)
    right.label(KChests.bag_label, h: 34, y: 12, a: :center, o: :alert)
    @ticker.label(@alerts[0], h: 32, y: 4, a: :center)
    lower_right.label(Game.party.money, h: 35, a: :right, x: -36, y: 6, f: 'Footlight MT Light', o: :frozen)
    lower_right.label(Game.terms(:money), h: 35, a: :right, x: -12, y: 6, f: 'Footlight MT Light', o: :frozen)
    @bars = [Sprite_Picture.new(58, 56, KChests::ITEM_BAR, z: 1000)]
    @bars << Sprite_Picture.new(458, 56, KChests::ITEM_BAR, z: 1000)
    vp = Viewport.new(328, 28, @w, @h)
    items = [] + Game.party.belongings
    max = items.size
    max.times {|n| @belongings << Sprite_Item.new(460, (n + 2) * 28 + 2, items[n], vp: vp, z: 1000) }
    vp = Viewport.new(8, 28, @w, @h)
    first_items = Game.settings.chests[@id] ||= Map.event.treasures
    left_size = first_items.size
    left_size.times {|n| @items << Sprite_Item.new(60, (n + 2) * 28 + 2, first_items[n], vp: vp, z: 1000) }
    remainder = @left_max - left_size
    remainder.times {|n| @items << Sprite_Item.new(60, (left_size + n + 2) * 28 + 2, nil, vp: vp, z: 1000) }
    @items[0].color = Color[:orange]
  end

  def update_scene
    if @alert_ticks == 0
      @alert_index = (@alert_index + 1) % @alerts.size
      @ticker[0] = @alerts[@alert_index]
      @alert_ticks = 40
    end
    @alert_ticks -= 1 if @alert_ticks > 0
    if press_quit?
      Game.cancel_se.play
      Map.event.close
      Game.last_scene
      return
    elsif hold_up?
      if @side == :left
        Game.cursor_se.play(0.7)
        @@up_ticks = 3
        @left_index = (@left_index + @left_max - 1) % @left_max
        @bars[0].y = 56 + @left_index * 28
      end
    elsif hold_down?
      if @side == :left
        Game.cursor_se.play(0.7)
        @@up_ticks = 3
        @left_index = (@left_index + 1) % @left_max
        @bars[0].y = 56 + @left_index * 28
      end
    end
  end

  def draw
    @spriteset.draw
    @ribbons.each {|s| s.draw }
    @bars.each {|s| s.draw }
    @items.each {|s| s.draw }
    @belongings.each {|s| s.draw }
  end
end

class GemRoulette < SceneBase
  def setup_bgm() Game.play_list(60, KUnitsGem::BGM) end
  def initialize
    super
    @items = KUnitsGem::ICONS
    @moving_frames = 15
    @steps = 72
    @gems = []
    @prizes = []
    @cx = 400
    @cy = 304
    @items += @items[0,(10 - @items.size)].dup if @items.size < 10
    @item_max = 10
    @spriteset = MapSpriteset.new
    @tone = Sprite_Panorama.new(Map.tone)
    @radius = 140
    @d = 2.0 * Math::PI / @item_max
    @item_max.times do |n|
      x = @cx - 20 - (@radius * Math.sin(@d * n)).round
      y = @cy - 60 + (@radius * Math.cos(@d * n)).round
      @gems << Sprite_BlinkIcon.new(x, y, @items[n], c: Color[:white].dup, z: 1100)
    end
    @points = @blink_index = @stage = 0
    @point_box = Sprite_Box.new(300, 68, w: 200, h: 26, c: :darkgreen, z: 1050)
    @point_box.label(KUnitsGem.points, x: 4, y: 4, o: :frozen)
    @point_box.label(@points, f: 'Footlight MT Light', h: 30, a: :right, x: -4, y: 4, o: :frozen)
    @prize_box = Sprite_Box.new(304, 300, w: 192, h: 26, c: :darkgreen, z: 1050)
    @prize_box.label(nil, a: :center, y: 4, o: :frozen)
    @prize_box.visible = nil
    @prizes_box = Sprite_Box.new(578, 220, w: 200, h: 104, c: :darkgreen, z: 1050)
    @prizes_box.label(KUnitsGem.prizes, a: :center, y: 4, o: :frozen)
    @spin_box = Sprite_Box.new(300, 436, w: 200, h: 26, c: :darkgreen, z: 1050)
    @spin_box.label(KUnitsGem.spins_left, x: 4, y: 4, o: :frozen)
    @prize_icon = Sprite_Icon.new(360, 226, 'void', z: 1050)
    @gems[@blink_index].blink = true
    @xy = [@gems[0].x, @gems[0].y]
    @options = CommandSpriteset.new(290, 480, 220, ['', KUnitsGem.spin_wheel])
    @options.z = 1100
  end

  def setup(id:, index:, spins:)
    @gem_roulette = GameData.gem_roulette[id]
    @rigged_index = @index = index
    @index = rand(@item_max) unless index
    @attempts = spins
    @spin_box.label(@attempts, f: 'Footlight MT Light', h: 30, a: :right, x: -4, y: 4, o: :frozen)
  end

  def update_animations() @gems[@blink_index].update end
  def update_scene
    @options.update
    case @stage
    when 0 then update_basic
    when 1 then update_sprites
    when 2 then update_prize
    end
  end

  def update_basic
    if press_quit?
      exit_scene
      return
    elsif press_enter?
      return Game.wrong_se.play(0.7) if @attempts == 0
      Game.ok_se.play(0.7)
      @attempts -= 1
      @spin_box[1] = @attempts
      @prize_box[0] = KUnitsGem.good_luck
      @prize_box.visible = true
      @gems[@blink_index].blink = nil
      @options.hide
      @stage = 1
    end
  end

  def update_sprites
    d1 = -@d / @moving_frames * 2
    @item_max.times do |n| m = n - @index
      d = @d * m + d1 * @steps
      @gems[n].x = @cx - 20 - (@radius * Math.sin(d)).round
      @gems[n].y = @cy - 60 + (@radius * Math.cos(d)).round
    end
    @steps -= 1
    return unless @steps < 0
    return @steps += 10 if rand(5) == 0
    Game.ok_se.play
    @steps = 1 + @moving_frames * (3 + rand(5))
    @blink_index = @index
    @gems[@blink_index].blink = true
    check_prize
  end

  def check_prize
    @points += points = @gem_roulette.points[@blink_index]
    Game.party.roulette_points += points
    @point_box[1] = @points
    @stage = 2
    @options.show
    prizes = @gem_roulette.prizes[@blink_index]
    return no_prize unless prizes[0]
    @new_prize = case prizes.size
    when 1 then prizes[0][0] ? prize_kind(prizes[0][0], prizes[0][1]) : nil
    else
      index = prizes.size > 2 ? rand(prizes.size) : rand(4) % 2
      prize_kind(prizes[index][0], prizes[index][1])
    end
    return no_prize unless @new_prize
    @prize_icon.change(@new_prize.icon, true)
    @prize_box[0] = @new_prize.name
    @options.refresh_commands(['', KUnitsGem.collect_prize])
  end

  def no_prize
    @kind = nil
    @index = @rigged_index || rand(@item_max)
    @prize_box[0] = KUnitsGem.next_time
    commands = ['', @attempts > 0 ? KUnitsGem.spin_wheel : KUnitsGem.run_out]
    @options.refresh_commands(commands)
    @stage = 0 if @attempts > 0
  end

  def prize_kind(kind, index)
    case @kind = kind
    when :item then GameData.items[index]
    when :weapon then GameData.weapons[index]
    when :armor then GameData.armors[index]
    when :skill then GameData.skills[index]
    when :hp, :mp then KUnitsGem::StatsItem.new(kind, index)
    end
  end

  def update_prize
    if !@kind and press_quit?
      exit_scene
      return
    elsif press_enter?
      @index = @rigged_index || rand(@item_max)
      commands = ['', @attempts > 0 ? KUnitsGem.spin_wheel : KUnitsGem.run_out]
      @options.refresh_commands(commands)
      case @kind
      when :item then Game.party.new_item(@new_prize)
      when :weapon then Game.party.new_weapon(@new_prize)
      when :armor then Game.party.new_armor(@new_prize)
      when :skill then Game.party.new_skill(@new_prize)
      when :hp then Game.party.leader.hp += @new_prize.points
      when :mp then Game.party.leader.mp += @new_prize.points
      end
      @prize_icon.change('')
      return exit_scene if @attempts == 0
      Game.ok_se.play(0.7)
      x = 580 + @prizes.size % 9 * 26
      y = 250 + @prizes.size / 9 * 26
      @prizes << Sprite_Icon.new(x, y, @new_prize.icon, z: 1060)
      @stage = 0
    end
  end

  def draw
    @spriteset.draw
    @tone.draw
    @gems.each {|sprite| sprite.draw }
    @prizes.each {|sprite| sprite.draw }
    @point_box.draw
    @prize_box.draw
    @prizes_box.draw
    @spin_box.draw
    @prize_icon.draw
    @options.draw
  end

  def exit_scene
    Game.cancel_se.play(0.7)
    Players.now.halt = @gem_roulette = nil
    Game.last_scene
  end
end

class SceneKBookPages < SceneBase
  def setup(id:)
    @id = id
    @index = 0
    @width = 8
    @book = []
    @pages = []
    @list_max = GameData.books.size
    book = GameData.books[@id]
    pages = book.pages
    @max = pages.size
    @max.times {|n| @book << Sprite_Page.new(400, 175, n, pages[n]) }
  end

  def update_animations
    return if @pages.empty?
    @pages[0].update
    @pages.shift unless @pages[0].flip?
  end

  def update_scene
    if press_quit?
      Game.cancel_se.play
      Game.last_scene
      return
    elsif press_left?
      return Game.wrong_se.play if @index == 0
      Game.page_se.play
      @index -= 1 unless  @index == @max - 1
      @pages = [@book[@index], @book[@index-1]]
      @index = [@index-1,0].max
      @pages.each {|page| page.flip(:left) }
      @ticks = 20
      return
    elsif press_right?
      return Game.wrong_se.play if @index == @max - 1
      Game.page_se.play
      @pages = @book[@index..@index+1]
      @pages.each {|page| page.flip(:right) }
      @index = [@index+2,@max-1].min
      @ticks = 20
    end
  end
  def draw() @book.each {|page| page.draw } end
end

class SceneMap < SceneBase
  attr_accessor :offset_x, :offset_y
  attr_reader :weather, :temp_x, :temp_y
  def kind() :map end
  def setup_bgm() Game.play_list(60, Map.bgm) end
  def temp_xy=(ary) @temp_x, @temp_y = ary end
  def initialize
    super
    @window = Window.now
    @map_ticks = 100
    @party = Game.party
    @party.money += 1000
    @player = Players.now
    @map_texts = Sprite_Box.new(Map.sign_x, Map.sign_y, h: 36, pic: 'wooden sign', z: 1000)
  end

  def setup(proc: Proc.new {})
    proc.call
    @offset_x = @player.offset_x
    @offset_y = @player.offset_y
    @map_texts.label(KUnitsMenu.labels[0], h: 30, a: :center, y: 16, o: :alert)
    @map_texts.label(Map.name, h: 36, a: :center, y: 42, o: :brown)
    @map_texts.label(Map.region, h: 28, a: :center, y: 72, o: :brown)
    setup_spriteset
  end

  def setup_spriteset
    @spriteset = MapSpriteset.new
    @tone = Sprite_Panorama.new(Map.tone)
    @weather = KUnitsWeather.new(1)
  end

  def finish_setup
    @player.visible = true
    @player.halt = nil
  end

  def update_scene
    @map_ticks -= 1 if @map_ticks > 0
    @weather.update
    @player.update
    @offset_x = @player.offset_x
    @offset_y = @player.offset_y
    Map.events.each {|e| e.update }
    @spriteset.update
    if press_quit?
      Game.cancel_se.play(0.7)
      Game.setup(SceneKUnitsMenu)
      return
    elsif button_down?(:caps_lock)
      Game.ok_se.play(0.7)
      Game.setup(SceneKUnitsAchieve)
      return
    elsif button_down?(:left_shift)
      Game.ok_se.play(0.7)
      Game.setup(SceneKBookPages, id: 1)
      return
    elsif button_down?(:left_ctrl)
      Game.ok_se.play(0.7)
      Game.setup(SceneKUnitsFoes)
    end
  end#def hold_button?(id) @@buttons[id] == @@hold_id and @@up_ticks == 0 end

  def draw(x=@offset_x, y=@offset_y)
    @window.clip_to(0,0,@window_width,@window_height) do
      @tone.draw
      @weather.draw
      @window.translate(x,y){ @spriteset.draw }
    end
    @map_texts.draw if @map_ticks > 0
  end

  def draw_no_weather(x=@offset_x, y=@offset_y)
    @window.clip_to(0,0,@window_width,@window_height) do
      @tone.draw
      @window.translate(x,y){ @spriteset.draw }
    end
  end
end

class SceneFight < SceneBase
  def kind() :fight end
  def setup_bgm() Game.play_list(60, Map.bgm) end
  def initialize
    
  end

  def setup(**options)
    @heroes = Game.party.heroes
    @foes = options[:foes]
  end

  def update_scene
    case @stage
    when 0 then nil
    when 1 then nil
    when 2 then nil
    end
  end

  def draw
    
  end
end