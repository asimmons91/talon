require "test/test_helper.rb"

class SceneTests
  class Recorder < Talon::Component
    prop :log, default: nil
    prop :id, default: nil

    on_start { log << [ :start, id ] }
    on_destroy { log << [ :destroy, id ] }
    on_update { log << [ :update, id ] }
    on_draw { log << [ :draw, id ] }
  end

  class SpawnsAndDestroys < Talon::Component
    prop :log, default: nil

    on_update do
      unless @done
        @done = true
        scene.spawn(:short_lived) { |go| go.add(Recorder, log: log, id: :short_lived) }.destroy
      end
    end
  end

  class Hero < Talon::GameObject
    state :hp, default: 100
  end

  class Health < Talon::Component
    state :hp, default: 100
  end

  class DestroysPartner < Talon::Component
    prop :partner, default: nil

    on_destroy { partner.destroy }
  end

  EVENTS = []

  class Level < Talon::Scene
    state :score, default: 0

    on_enter { |args| EVENTS << [ :enter, args ] }
    on_exit { |args| EVENTS << [ :exit, args ] }
  end

  class Empty < Talon::Scene; end

  class NamedHooks < Talon::Scene
    on_enter :setup
    on_exit :cleanup

    def setup(args)
      EVENTS << [ :setup, args ]
    end

    def cleanup(_args)
      EVENTS << :cleanup
    end
  end

  class ReadsScoreOnExit < Talon::Scene
    state :score, default: 0

    on_exit { EVENTS << [ :exit_score, score ] }
  end

  def scene_with_args(args, klass = Empty)
    scene = klass.new
    scene.args = args
    scene
  end

  def test_spawn_builds_a_game_object_in_the_scene(args, assert)
    scene = scene_with_args(args)
    go = scene.spawn(:player, tags: [ :hero ])

    assert.equal! go.name, :player
    assert.equal! go.scene, scene
    assert.true! go.args.equal?(args), "spawned objects should take the scene's args"
    assert.true! go.tagged?(:hero)
  end

  def test_spawn_runs_prefabs_in_order_then_the_block(args, assert)
    order = []
    first = ->(go) { order << [ :first, go.name ] }
    second = ->(_go) { order << :second }
    scene_with_args(args).spawn(:built, first, second) { |_go| order << :block }

    assert.equal! order, [ [ :first, :built ], :second, :block ]
  end

  def test_spawned_objects_join_on_the_next_tick(args, assert)
    scene = scene_with_args(args)
    scene.spawn(:a)
    scene.spawn(:b)

    assert.equal! scene.map(&:name), []
    scene.tick
    assert.equal! scene.map(&:name), [ :a, :b ]
  end

  def test_each_without_a_block_returns_an_enumerator(args, assert)
    scene = scene_with_args(args)
    scene.spawn(:a, tags: [ :enemy ])
    scene.spawn(:b)
    scene.tick

    assert.equal! scene.each.next.name, :a
    assert.equal! scene.count, 2
    assert.equal! scene.find { |go| go.tagged?(:enemy) }.name, :a
  end

  def test_tick_updates_every_object_before_drawing(args, assert)
    log = []
    scene = scene_with_args(args)
    scene.spawn(:a) { |go| go.add(Recorder, log: log, id: :a) }
    scene.spawn(:b) { |go| go.add(Recorder, log: log, id: :b) }
    scene.tick

    assert.equal! log, [ [ :start, :a ], [ :update, :a ], [ :start, :b ], [ :update, :b ], [ :draw, :a ], [ :draw, :b ] ]
  end

  def test_destroyed_objects_finish_the_tick_then_are_removed(args, assert)
    log = []
    scene = scene_with_args(args)
    go = scene.spawn(:doomed) { |g| g.add(Recorder, log: log, id: :doomed) }
    scene.tick
    go.destroy
    log.clear
    scene.tick

    assert.equal! log, [ [ :update, :doomed ], [ :draw, :doomed ], [ :destroy, :doomed ] ]
    assert.equal! scene.to_a, []
  end

  def test_objects_spawned_and_destroyed_in_one_tick_never_update(args, assert)
    log = []
    scene = scene_with_args(args)
    scene.spawn(:spawner) { |go| go.add(SpawnsAndDestroys, log: log) }
    scene.tick
    scene.tick

    assert.equal! log, [ [ :destroy, :short_lived ] ]
    assert.equal! scene.map(&:name), [ :spawner ]
  end

  def test_destroying_twice_tears_down_once(args, assert)
    log = []
    scene = scene_with_args(args)
    go = scene.spawn(:doomed) { |g| g.add(Recorder, log: log, id: :doomed) }
    scene.tick
    go.destroy
    go.destroy
    scene.tick
    go.destroy
    scene.tick

    assert.equal! events_of(log, :destroy), [ :doomed ]
  end

  def test_destroy_callbacks_can_destroy_other_objects(args, assert)
    log = []
    scene = scene_with_args(args)
    partner = scene.spawn(:partner) { |go| go.add(Recorder, log: log, id: :partner) }
    first = scene.spawn(:first) { |go| go.add(DestroysPartner, partner: partner) }
    scene.tick
    first.destroy
    scene.tick

    assert.equal! events_of(log, :destroy), [ :partner ]
    assert.equal! scene.to_a, []
  end

  def test_respawned_objects_start_with_fresh_state(args, assert)
    scene = scene_with_args(args)
    enemy = scene.spawn(:enemy) { |go| go.add(Health) }
    hero = Hero.new(:hero, scene: scene)
    scene.tick
    enemy[Health].hp = 5
    hero.hp = 5
    enemy.destroy
    hero.destroy
    scene.tick

    assert.equal! scene.spawn(:enemy) { |go| go.add(Health) }[Health].hp, 100
    assert.equal! Hero.new(:hero, scene: scene).hp, 100
  end

  def test_same_tick_respawn_keeps_the_new_objects_state(args, assert)
    scene = scene_with_args(args)
    old = scene.spawn(:player) { |go| go.add(Health) }
    scene.tick
    old.destroy
    fresh = scene.spawn(:player) { |go| go.add(Health) }
    fresh[Health].hp = 50
    scene.tick

    assert.equal! fresh[Health].hp, 50
    assert.equal! scene.map(&:name), [ :player ]
  end

  def test_scene_teardown_clears_scene_object_and_component_state(args, assert)
    EVENTS.clear
    scene = scene_with_args(args, Level)
    scene.score = 9
    go = scene.spawn(:player) { |g| g.add(Health, hp: 3) }
    hero = Hero.new(:hero, scene: scene, hp: 4)
    scene.tick
    go[Health].hp
    hero.hp
    scene.teardown

    assert.nil! args.state.scenes[:"SceneTests::Level"]
    assert.nil! args.state.objects[:"SceneTests::Level"]
    assert.nil! args.state.components[:"SceneTests::Level"]
  end

  def test_enter_and_exit_accept_method_names(args, assert)
    EVENTS.clear
    scene = scene_with_args(args, NamedHooks)
    scene.run_callbacks(:enter, args)
    scene.teardown

    assert.equal! EVENTS.size, 2
    assert.true! EVENTS[0][1].equal?(args), "named enter callback should receive args"
    assert.equal! EVENTS[1], :cleanup
  end

  def test_exit_callbacks_can_read_scene_state(args, assert)
    EVENTS.clear
    scene = scene_with_args(args, ReadsScoreOnExit)
    scene.score = 6
    scene.teardown

    assert.equal! EVENTS, [ [ :exit_score, 6 ] ]
  end

  def test_a_new_instance_starts_from_defaults_after_teardown(args, assert)
    EVENTS.clear
    old = scene_with_args(args, Level)
    old.score = 9
    old.teardown

    assert.equal! scene_with_args(args, Level).score, 0
  end

  def test_teardown_runs_exit_and_destroys_every_object(args, assert)
    EVENTS.clear
    log = []
    scene = scene_with_args(args, Level)
    scene.spawn(:live) { |go| go.add(Recorder, log: log, id: :live) }
    scene.tick
    scene.spawn(:pending) { |go| go.add(Recorder, log: log, id: :pending) }
    scene.teardown

    assert.equal! EVENTS.size, 1
    assert.equal! EVENTS[0][0], :exit
    assert.true! EVENTS[0][1].equal?(args), "exit callbacks should receive args"
    assert.equal! events_of(log, :destroy), [ :live, :pending ]
    assert.equal! scene.to_a, []
    scene.tick
    assert.equal! scene.to_a, []
  end

  def test_setting_args_passes_them_to_live_and_pending_objects(args, assert)
    scene = Empty.new
    live = scene.spawn(:live)
    scene.tick
    pending = scene.spawn(:pending)
    scene.args = args

    assert.true! live.args.equal?(args), "live objects should receive args"
    assert.true! pending.args.equal?(args), "pending objects should receive args"
  end

  def test_state_is_stored_per_scene_class(args, assert)
    scene = Level.new(score: 3)
    scene.args = args
    scene.score += 1

    assert.equal! args.state.scenes[:"SceneTests::Level"], { score: 4 }
  end

  def test_spawn_passes_state_keywords_through(args, assert)
    scene = scene_with_args(args)
    hero = Hero.new(:hero, scene: scene, hp: 7)

    assert.equal! hero.hp, 7
  end

  def test_unknown_keywords_raise(args, assert)
    scene = scene_with_args(args)
    scene_error = capture_error(ArgumentError) { Level.new(scroe: 1) }
    spawn_error = capture_error(ArgumentError) { scene.spawn(:typo, hp: 5) }

    assert.equal! scene_error&.message, "unknown keyword: :scroe"
    assert.equal! spawn_error&.message, "unknown keyword: :hp"
  end

  def events_of(log, kind)
    log.select { |entry| entry[0] == kind }.map { |entry| entry[1] }
  end
end
