# Run with: ./dragonruby . --test test/talon_tests.rb

require "lib/talon.rb"

module TalonTests
  class Recorder < Talon::Component
    prop :log, default: nil

    on_start { |args| log << [ :start, args ] }
    on_destroy { log << :destroy }
    on_update { |args| log << [ :update, args ] }
    on_draw :record_draw

    def record_draw(args)
      log << [ :draw, args ]
    end
  end

  class SpecialRecorder < Recorder; end

  class Counter < Talon::Component
    state :count, default: 0

    on_update { self.count += 1 }
  end

  class LevelScene < Talon::Scene
    state :entered, default: 0

    set_callback(:enter) do
      self.entered += 1
      spawn(:counter) { |go| go.add(Counter, count: 10) }
    end
  end

  EXIT_LOG = []

  class ExitScene < Talon::Scene
    set_callback(:exit) { EXIT_LOG << :exit }
  end

  class OtherScene < Talon::Scene; end

  class ParentState
    include Talon::Stateful

    state :a, default: 1
  end

  class ChildState < ParentState
    state :b, default: 2
  end

  class Hero < Talon::GameObject
    state :hp, default: 100
  end
end

def test_component_class_is_named_component(_args, assert)
  assert.true! Talon.const_defined?(:Component), "Talon::Component should be defined"
end

def test_game_object_finds_components_by_class(_args, assert)
  go = Talon::GameObject.new(:lookup)
  recorder = TalonTests::SpecialRecorder.new(log: [])
  go << recorder

  assert.equal! go[TalonTests::SpecialRecorder], recorder
  assert.equal! go[TalonTests::Recorder], recorder
  assert.equal! go[TalonTests::Counter], nil
end

def test_component_lifecycle_receives_args(args, assert)
  log = []
  scene = TalonTests::OtherScene.new
  scene.args = args
  go = scene.spawn(:recorder) { |g| g.add(TalonTests::Recorder, log: log) }

  scene.tick
  scene.tick
  go.destroy
  scene.tick

  assert.equal! log.count { |e| e.is_a?(Array) && e[0] == :start }, 1
  assert.equal! log.count { |e| e.is_a?(Array) && e[0] == :update }, 3
  assert.equal! log.count { |e| e.is_a?(Array) && e[0] == :draw }, 3
  assert.true! log.select { |e| e.is_a?(Array) }.all? { |e| e[1].equal?(args) }, "hooks should receive args"
  assert.equal! log.last, :destroy
  assert.equal! scene.to_a, []
end

def test_scene_is_enumerable(args, assert)
  scene = TalonTests::OtherScene.new
  scene.args = args
  scene.spawn(:a)
  scene.spawn(:b)

  assert.equal! scene.map(&:name), []
  scene.tick
  assert.equal! scene.map(&:name), [ :a, :b ]
end

def test_game_enters_scene_and_passes_args_down(args, assert)
  scene = TalonTests::LevelScene.new
  game = Talon::Game.new(scene)
  game.args = args

  game.tick
  game.tick

  counter = scene.first[TalonTests::Counter]
  assert.equal! scene.entered, 1
  assert.true! counter.args.equal?(args), "components should receive args from the game"
  assert.equal! counter.count, 12
end

def test_change_scene_runs_exit_and_destroy_callbacks(args, assert)
  log = []
  scene = TalonTests::ExitScene.new
  game = Talon::Game.new(scene)
  game.args = args
  game.tick
  scene.spawn(:recorder) { |g| g.add(TalonTests::Recorder, log: log) }
  game.tick

  game.change_scene(TalonTests::OtherScene.new)
  game.tick

  assert.equal! TalonTests::EXIT_LOG, [ :exit ]
  assert.equal! log.last, :destroy
end

def test_subclass_state_does_not_leak_into_parent(_args, assert)
  assert.equal! TalonTests::ChildState.state_defaults, { a: 1, b: 2 }
  assert.equal! TalonTests::ParentState.state_defaults, { a: 1 }
end

def test_game_object_state_from_keywords(args, assert)
  scene = TalonTests::OtherScene.new
  scene.args = args
  hero = TalonTests::Hero.new(:hero, scene: scene, hp: 5)

  assert.equal! hero.hp, 5
end

module TalonTests
  class TwoBlocks < Talon::Component
    prop :log, default: nil

    on_start { log << :first }
    on_start { |_args| log << :second }
    on_update { log << :update_first }
    on_update { |_args| log << :update_second }
  end

  class SingleUpdate < Talon::Component
    prop :log, default: nil

    on_update { |args| log << args }
  end

  class Reloaded < Talon::Component
    prop :log, default: nil
  end
end

def test_multiple_blocks_for_one_hook_all_run(args, assert)
  log = []
  go = Talon::GameObject.new(:two_blocks)
  go.args = args
  go.add(TalonTests::TwoBlocks, log: log)
  go.update

  assert.equal! log, [ :first, :second, :update_first, :update_second ]
end

def test_single_update_block_is_a_public_method(args, assert)
  log = []
  component = TalonTests::SingleUpdate.new(log: log)

  assert.true! component.respond_to?(:update), "update should be public"
  component.update(args)
  assert.true! log.first.equal?(args), "update should receive args"
end

def test_reregistering_in_a_later_tick_replaces_callbacks(args, assert)
  klass = TalonTests::Reloaded
  generation = 1
  klass.define_singleton_method(:callback_generation) { generation }

  klass.on_start { log << :old_start }
  klass.on_update { log << :old_update }
  generation = 2
  klass.on_start { log << :new_start }
  klass.on_update { log << :new_update }

  log = []
  go = Talon::GameObject.new(:reloaded)
  go.args = args
  go.add(klass, log: log)
  go.update

  assert.equal! log, [ :new_start, :new_update ]
end

def test_unknown_keywords_raise(args, assert)
  scene = TalonTests::OtherScene.new
  scene.args = args

  [
    -> { TalonTests::OtherScene.new(bogus: 1) },
    -> { Talon::Game.new(scene, bogus: 1) },
    -> { scene.spawn(:typo, hp: 5) },
    -> { TalonTests::Counter.new(cuont: 1) }
  ].each do |build|
    raised = begin
      build.call
      nil
    rescue ArgumentError => e
      e
    end
    assert.true! raised && raised.message.include?("unknown keyword"), "expected ArgumentError, got #{raised.inspect}"
  end
end

module TalonTests
  class ThreeCalls < Talon::Component
    prop :log, default: nil

    on_update :named
    on_update { log << :zero }
    on_update { |args| log << args }

    def named(args)
      log << [ :named, args ]
    end
  end

  class FiveCalls < Talon::Component
    prop :log, default: nil

    on_draw { log << 1 }
    on_draw { |_args| log << 2 }
    on_draw :third, :fourth
    on_draw { log << 5 }

    def third(_args) = log << 3
    def fourth(_args) = log << 4
  end
end

def test_three_update_callbacks_run_in_order(args, assert)
  log = []
  TalonTests::ThreeCalls.new(log: log).update(args)

  assert.equal! log.size, 3
  assert.equal! log[0][0], :named
  assert.true! log[0][1].equal?(args), "named method should receive args"
  assert.equal! log[1], :zero
  assert.true! log[2].equal?(args), "block should receive args"
end

def test_long_draw_chain_runs_in_order(args, assert)
  log = []
  TalonTests::FiveCalls.new(log: log).draw(args)

  assert.equal! log, [ 1, 2, 3, 4, 5 ]
end
