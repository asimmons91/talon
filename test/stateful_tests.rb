require "test/test_helper.rb"

class StatefulTests
  class Box
    include Talon::Stateful

    state :count, default: 0
    state :label

    attr_reader :store

    def initialize(store = {}, **values)
      @store = store
      assign_state(values)
    end

    private

    def state_store
      @store
    end
  end

  class BigBox < Box
    state :size, default: 10
  end

  class NoStore
    include Talon::Stateful

    state :value, default: 1
  end

  def test_state_uses_its_default(_args, assert)
    box = Box.new

    assert.equal! box.count, 0
    assert.nil! box.label
  end

  def test_keywords_set_the_initial_value(_args, assert)
    assert.equal! Box.new(count: 3).count, 3
  end

  def test_writes_go_to_the_state_store(_args, assert)
    box = Box.new
    box.count = 4

    assert.equal! box.store, { count: 4 }
    assert.equal! box.count, 4
  end

  def test_values_are_stored_on_first_read(_args, assert)
    box = Box.new(count: 2)

    assert.equal! box.store, {}
    box.count
    assert.equal! box.store, { count: 2 }
  end

  def test_stored_values_win_over_keywords_and_defaults(_args, assert)
    box = Box.new({ count: 7, label: "kept" }, count: 1)

    assert.equal! box.count, 7
    assert.equal! box.label, "kept"
  end

  def test_subclasses_inherit_state_without_changing_the_parent(_args, assert)
    big = BigBox.new(count: 1)

    assert.equal! [ big.count, big.size ], [ 1, 10 ]
    assert.equal! BigBox.state_defaults, { count: 0, label: nil, size: 10 }
    assert.equal! Box.state_defaults, { count: 0, label: nil }
  end

  def test_unknown_keywords_raise(_args, assert)
    one = capture_error(ArgumentError) { Box.new(cuont: 1) }
    two = capture_error(ArgumentError) { Box.new(cuont: 1, lable: "x") }

    assert.equal! one&.message, "unknown keyword: :cuont"
    assert.equal! two&.message, "unknown keywords: :cuont, :lable"
  end

  def test_reading_state_without_a_state_store_raises(_args, assert)
    error = capture_error(NotImplementedError) { NoStore.new.value }

    assert.true! error, "expected NotImplementedError"
  end
end
