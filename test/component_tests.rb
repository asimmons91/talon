require "test/test_helper.rb"

class ComponentTests
  class Mover < Talon::Component
    prop :speed, default: 2
    state :x, default: 0

    on_update { self.x += speed }
  end

  class Health < Talon::Component
    state :hp, default: 100
  end

  class Level < Talon::Scene; end

  def spawn_with(args, name, *components)
    scene = Level.new
    scene.args = args
    scene.spawn(name) { |go| components.each { |c| go << c } }
  end

  def test_components_start_enabled(_args, assert)
    mover = Mover.new

    assert.true! mover.enabled?
    mover.enabled = false
    assert.false! mover.enabled?
  end

  def test_keywords_set_props_and_state(args, assert)
    mover = Mover.new(speed: 3, x: 5)
    spawn_with(args, :mover, mover)

    assert.equal! [ mover.speed, mover.x ], [ 3, 5 ]
  end

  def test_unknown_keywords_raise(_args, assert)
    error = capture_error(ArgumentError) { Mover.new(sped: 3) }

    assert.equal! error&.message, "unknown keyword: :sped"
  end

  def test_scene_is_the_game_objects_scene(args, assert)
    mover = Mover.new
    go = spawn_with(args, :mover, mover)

    assert.equal! mover.go, go
    assert.equal! mover.scene, go.scene
  end

  def test_reading_state_before_attaching_to_a_scene_raises(_args, assert)
    error = capture_error(RuntimeError) { Mover.new.x }

    assert.true! error&.message&.include?("attached to a scene"), "expected RuntimeError, got #{error.inspect}"
  end

  def test_state_is_stored_per_scene_object_and_component(args, assert)
    mover = Mover.new(x: 7)
    spawn_with(args, :player, mover, Health.new(hp: 50))
    mover.x

    assert.equal! args.state.components[:"ComponentTests::Level"][:player][:"ComponentTests::Mover"], { x: 7 }
  end

  def test_state_is_separate_per_game_object(args, assert)
    a = Health.new
    b = Health.new
    spawn_with(args, :a, a)
    spawn_with(args, :b, b)
    a.hp = 1

    assert.equal! [ a.hp, b.hp ], [ 1, 100 ]
  end

  def test_components_of_the_same_class_have_separate_state(args, assert)
    first = Health.new
    second = Health.new
    spawn_with(args, :player, first, second)
    first.hp = 1

    assert.equal! [ first.hp, second.hp ], [ 1, 100 ]
    assert.equal! args.state.components[:"ComponentTests::Level"][:player].keys,
                  [ :"ComponentTests::Health", :"ComponentTests::Health#2" ]
  end

  def test_on_update_changes_state_each_update(args, assert)
    mover = Mover.new(speed: 4)
    go = spawn_with(args, :mover, mover)
    go.update
    go.update

    assert.equal! mover.x, 8
  end
end
