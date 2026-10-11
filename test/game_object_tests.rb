require "test/test_helper.rb"

class GameObjectTests
  class Recorder < Talon::Component
    prop :log, default: nil
    prop :id, default: nil

    on_start { |args| log << [ :start, id, args ] }
    on_destroy { log << [ :destroy, id ] }
    on_update { |args| log << [ :update, id, args ] }
    on_draw :record_draw

    def record_draw(args)
      log << [ :draw, id, args ]
    end
  end

  class SpecialRecorder < Recorder; end

  class StartOnly < Talon::Component
    prop :log, default: nil

    on_start { log << :start }
  end

  class TwoStarts < Talon::Component
    prop :log, default: nil

    on_start { log << :first }
    on_start { |_args| log << :second }
    on_update { log << :update_first }
    on_update { |_args| log << :update_second }
  end

  class Hero < Talon::GameObject
    state :hp, default: 100
  end

  class Enabler < Talon::Component
    prop :target, default: nil

    on_update { target.enabled = true }
  end

  class Health < Talon::Component
    state :hp, default: 100
  end

  class Level < Talon::Scene; end

  def object_with_args(args, name = :object)
    go = Talon::GameObject.new(name)
    go.args = args
    go
  end

  def events(log, kind)
    log.select { |entry| entry[0] == kind }
  end

  def test_name_and_tags(_args, assert)
    go = Talon::GameObject.new(:player, tags: [ :hero, :solid ])

    assert.equal! go.name, :player
    assert.equal! go.tags, [ :hero, :solid ]
    assert.true! go.tagged?(:hero)
    assert.false! go.tagged?(:enemy)
    assert.equal! Talon::GameObject.new(:plain).tags, []
  end

  def test_initialize_yields_the_new_object(_args, assert)
    yielded = nil
    go = Talon::GameObject.new(:block) { |g| yielded = g }

    assert.equal! yielded, go
  end

  def test_add_and_shovel_attach_components_and_return_self(args, assert)
    go = object_with_args(args)
    recorder = Recorder.new(log: [])

    assert.equal! go.add(StartOnly, log: []), go
    assert.equal! go << recorder, go
    assert.equal! recorder.go, go
    assert.true! recorder.args.equal?(args), "attached components should get the object's args"
  end

  def test_lookup_by_class(_args, assert)
    go = Talon::GameObject.new(:lookup)
    special = SpecialRecorder.new(log: [])
    go << special

    assert.equal! go[SpecialRecorder], special
    assert.equal! go[Recorder], special
    assert.nil! go[StartOnly]
  end

  def test_lookup_prefers_an_exact_class_match(_args, assert)
    go = Talon::GameObject.new(:lookup)
    special = SpecialRecorder.new(log: [])
    plain = Recorder.new(log: [])
    go << special << plain

    assert.equal! go[Recorder], plain
    assert.equal! go[SpecialRecorder], special
  end

  def test_start_runs_once_before_the_first_update(args, assert)
    log = []
    go = object_with_args(args)
    go.add(Recorder, log: log, id: 1)
    go.update
    go.update

    assert.equal! log.map(&:first), [ :start, :update, :update ]
    assert.true! log.all? { |entry| entry[2].equal?(args) }, "hooks should receive args"
  end

  def test_multiple_blocks_for_one_hook_all_run(args, assert)
    log = []
    go = object_with_args(args)
    go.add(TwoStarts, log: log)
    go.update

    assert.equal! log, [ :first, :second, :update_first, :update_second ]
  end

  def test_components_draw_once_started(args, assert)
    log = []
    go = object_with_args(args)
    go.add(Recorder, log: log, id: 1)
    go.draw
    assert.equal! log, []

    go.update
    log.clear
    go.draw
    assert.equal! log, [ [ :draw, 1, args ] ]
  end

  def test_components_without_update_or_draw_only_start(args, assert)
    log = []
    go = object_with_args(args)
    go.add(StartOnly, log: log)
    go.update
    go.draw
    go.update

    assert.equal! log, [ :start ]
  end

  def test_disabled_components_skip_update_and_draw(args, assert)
    log = []
    go = object_with_args(args)
    off = Recorder.new(log: log, id: :off)
    off.enabled = false
    go << off
    go.add(Recorder, log: log, id: :on)
    go.update
    go.draw

    assert.equal! events(log, :update).map { |e| e[1] }, [ :on ]
    assert.equal! events(log, :draw).map { |e| e[1] }, [ :on ]
  end

  def test_inactive_objects_do_nothing_until_reactivated(args, assert)
    log = []
    go = object_with_args(args)
    go.add(Recorder, log: log, id: 1)
    go.active = false

    go.update
    go.draw
    assert.false! go.active?
    assert.equal! log, []

    go.active = true
    go.update
    assert.equal! log.map(&:first), [ :start, :update ]
  end

  def test_teardown_runs_destroy_callbacks(args, assert)
    log = []
    go = object_with_args(args)
    go.add(Recorder, log: log, id: 1).add(StartOnly, log: log)
    go.teardown

    assert.equal! log, [ [ :destroy, 1 ] ]
  end

  def test_setting_args_passes_them_to_components(args, assert)
    go = Talon::GameObject.new(:object)
    recorder = Recorder.new(log: [])
    go << recorder
    go.args = args

    assert.true! recorder.args.equal?(args), "components should receive the object's args"
  end

  def test_destroy_queues_removal_from_the_scene(args, assert)
    scene = Level.new
    scene.args = args
    go = scene.spawn(:doomed)
    scene.tick
    go.destroy

    assert.equal! scene.map(&:name), [ :doomed ]
    scene.tick
    assert.equal! scene.to_a, []
  end

  def test_state_comes_from_keywords_and_is_stored_per_scene(args, assert)
    scene = Level.new
    scene.args = args
    hero = Hero.new(:hero, scene: scene, hp: 5)

    assert.true! hero.args.equal?(args), "objects should take their scene's args"
    assert.equal! hero.hp, 5
    assert.equal! args.state.objects[:"GameObjectTests::Level"][:hero], { hp: 5 }
  end

  def test_unknown_keywords_raise(_args, assert)
    error = capture_error(ArgumentError) { Hero.new(:hero, hpp: 1) }

    assert.equal! error&.message, "unknown keyword: :hpp"
  end

  def test_components_of_the_same_class_all_run(args, assert)
    log = []
    go = object_with_args(args)
    first = Recorder.new(log: log, id: 1)
    second = Recorder.new(log: log, id: 2)
    go << first << second
    go.update
    go.teardown

    assert.equal! go.components, [ first, second ]
    assert.equal! go[Recorder], first
    assert.equal! events(log, :start).map { |e| e[1] }, [ 1, 2 ]
    assert.equal! events(log, :update).map { |e| e[1] }, [ 1, 2 ]
    assert.equal! events(log, :destroy).map { |e| e[1] }, [ 1, 2 ]
  end

  def test_teardown_only_runs_once(args, assert)
    log = []
    go = object_with_args(args)
    go.add(Recorder, log: log, id: 1)

    assert.false! go.destroyed?
    go.teardown
    go.teardown
    assert.true! go.destroyed?
    assert.equal! log, [ [ :destroy, 1 ] ]
  end

  def test_teardown_clears_object_and_component_state(args, assert)
    scene = Level.new
    scene.args = args
    hero = Hero.new(:hero, scene: scene, hp: 5)
    hero.add(Health, hp: 7)
    hero.hp
    hero[Health].hp
    hero.teardown

    assert.equal! args.state.objects[:"GameObjectTests::Level"], {}
    assert.equal! args.state.components[:"GameObjectTests::Level"], {}
  end

  def test_teardown_can_keep_state(args, assert)
    scene = Level.new
    scene.args = args
    hero = Hero.new(:hero, scene: scene, hp: 5)
    hero.hp
    hero.teardown(forget_state: false)

    assert.equal! args.state.objects[:"GameObjectTests::Level"][:hero], { hp: 5 }
  end

  def test_disabled_components_start_once_enabled(args, assert)
    log = []
    go = object_with_args(args)
    recorder = Recorder.new(log: log, id: 1)
    recorder.enabled = false
    go << recorder

    go.update
    go.draw
    assert.equal! log, []

    recorder.enabled = true
    go.update
    go.draw
    assert.equal! log.map(&:first), [ :start, :update, :draw ]
  end

  def test_components_enabled_mid_update_wait_for_their_start(args, assert)
    log = []
    go = object_with_args(args)
    recorder = Recorder.new(log: log, id: 1)
    recorder.enabled = false
    go.add(Enabler, target: recorder)
    go << recorder

    go.update
    assert.equal! log, []

    go.update
    assert.equal! log.map(&:first), [ :start, :update ]
  end

  def test_reading_state_without_a_scene_raises(_args, assert)
    error = capture_error(RuntimeError) { Hero.new(:lonely).hp }

    assert.true! error&.message&.include?("added to a scene"), "expected RuntimeError, got #{error.inspect}"
  end
end
