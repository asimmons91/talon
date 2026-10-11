require "test/test_helper.rb"

class GameTests
  class Counter < Talon::Component
    state :count, default: 0

    on_update { self.count += 1 }
  end

  class ArgsRecorder < Talon::Component
    prop :log, default: nil

    on_update { |args| log << args }
  end

  class Recorder < Talon::Component
    prop :log, default: nil

    on_destroy { log << :destroy }
  end

  EVENTS = []

  class Level < Talon::Scene
    state :entered, default: 0

    on_enter do |args|
      EVENTS << [ :enter_level, args ]
      self.entered += 1
      spawn(:counter) { |go| go.add(Counter, count: 10) }
    end

    on_exit { EVENTS << :exit_level }
  end

  class Menu < Talon::Scene
    on_enter { EVENTS << :enter_menu }
  end

  class Empty < Talon::Scene; end

  class Session < Talon::Game
    state :lives, default: 3
  end

  def game_with_args(args, scene)
    game = Talon::Game.new(scene)
    game.args = args
    game
  end

  def test_first_tick_enters_and_ticks_the_scene(args, assert)
    EVENTS.clear
    scene = Level.new
    game = game_with_args(args, scene)
    game.tick

    assert.equal! scene.game, game
    assert.true! scene.args.equal?(args), "scene should receive the game's args"
    assert.equal! EVENTS.size, 1
    assert.true! EVENTS[0][1].equal?(args), "enter callbacks should receive args"
    assert.equal! scene.first[Counter].count, 11
  end

  def test_enter_runs_once_and_args_reach_components(args, assert)
    EVENTS.clear
    scene = Level.new
    game = game_with_args(args, scene)
    game.tick
    game.tick

    counter = scene.first[Counter]
    assert.equal! scene.entered, 1
    assert.true! counter.args.equal?(args), "components should receive args from the game"
    assert.equal! counter.count, 12
  end

  def test_change_scene_waits_for_the_next_tick(args, assert)
    EVENTS.clear
    log = []
    level = Level.new
    game = game_with_args(args, level)
    game.tick
    level.spawn(:recorder) { |go| go.add(Recorder, log: log) }
    game.tick
    EVENTS.clear

    menu = Menu.new
    game.change_scene(menu)
    assert.equal! EVENTS, []

    game.tick
    assert.equal! EVENTS, [ :exit_level, :enter_menu ]
    assert.equal! log, [ :destroy ]
    assert.equal! level.to_a, []
    assert.equal! menu.game, game
  end

  def test_reentering_a_scene_class_starts_fresh(args, assert)
    EVENTS.clear
    first = Level.new
    game = game_with_args(args, first)
    game.tick
    game.change_scene(Menu.new)
    game.tick
    second = Level.new
    game.change_scene(second)
    game.tick

    assert.equal! second.entered, 1
    assert.equal! second.first[Counter].count, 11
  end

  def test_new_args_are_passed_down_on_the_next_tick(args, assert)
    log = []
    scene = Empty.new
    game = game_with_args(args, scene)
    game.tick
    scene.spawn(:recorder) { |go| go.add(ArgsRecorder, log: log) }
    game.tick

    replacement = Object.new
    game.args = replacement
    game.tick

    assert.true! scene.args.equal?(replacement), "scene should receive new args"
    assert.true! log.last.equal?(replacement), "components should receive new args"
  end

  def test_game_state_comes_from_keywords(args, assert)
    game = Session.new(Empty.new, lives: 5)
    game.args = args

    assert.equal! game.lives, 5
    assert.equal! args.state.game, { lives: 5 }
  end

  def test_unknown_keywords_raise(_args, assert)
    error = capture_error(ArgumentError) { Session.new(Empty.new, livse: 1) }

    assert.equal! error&.message, "unknown keyword: :livse"
  end

  def test_version_is_a_semantic_version(_args, assert)
    parts = Talon::VERSION.split(".")

    assert.equal! parts.size, 3
    assert.true! parts.all? { |part| part.to_i.to_s == part }, "VERSION should look like x.y.z"
  end
end
