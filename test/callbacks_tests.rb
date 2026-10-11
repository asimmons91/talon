require "test/test_helper.rb"

class CallbacksTests
  class Recorder
    include Talon::Callbacks

    attr_reader :log

    def initialize
      @log = []
    end
  end

  class Chained < Recorder
    set_callback(:ping, :named)
    set_callback(:ping) { |args| log << [ :block, args ] }
    set_callback(:ping) { log << :no_args }

    def named(args)
      log << [ :named, args ]
    end
  end

  class ChainedChild < Chained
    set_callback(:ping) { log << :child }
  end

  class LateNamed < Recorder
    define_callback(:step, :advance)

    def advance(args)
      log << [ :advance, args ]
    end
  end

  class ZeroArgBlock < Recorder
    define_callback(:step) { log << :step }
  end

  class Overridden < Recorder
    define_callback(:step) { |_args| log << :parent }
  end

  class Overriding < Overridden
    define_callback(:step) { |_args| log << :child }
  end

  class Inheriting < Overridden; end

  class TwoCalls < Recorder
    define_callback(:step) { log << 1 }
    define_callback(:step) { |args| log << args }
  end

  class ThreeCalls < Recorder
    define_callback(:step, :named)
    define_callback(:step) { log << :zero }
    define_callback(:step) { |args| log << args }

    def named(args)
      log << [ :named, args ]
    end
  end

  class FiveCalls < Recorder
    define_callback(:step) { log << 1 }
    define_callback(:step) { |_args| log << 2 }
    define_callback(:step, :third, :fourth)
    define_callback(:step) { log << 5 }

    def third(_args)
      log << 3
    end

    def fourth(_args)
      log << 4
    end
  end

  class Reloaded < Recorder; end

  def test_run_callbacks_calls_methods_and_blocks_in_order(_args, assert)
    target = Chained.new
    target.run_callbacks(:ping, :payload)

    assert.equal! target.log, [ [ :named, :payload ], [ :block, :payload ], :no_args ]
  end

  def test_subclass_callbacks_run_after_the_parents(_args, assert)
    child = ChainedChild.new
    child.run_callbacks(:ping, :payload)
    parent = Chained.new
    parent.run_callbacks(:ping, :payload)

    assert.equal! child.log.last, :child
    assert.equal! child.log.size, 4
    assert.equal! parent.log.size, 3
  end

  def test_callbacks_for_lists_names_and_arity(_args, assert)
    chain = Chained.callbacks_for(:ping)

    assert.equal! chain.first, [ :named, true ]
    assert.equal! chain.map(&:last), [ true, true, false ]
    assert.equal! ChainedChild.callbacks_for(:ping).size, 4
    assert.equal! Chained.callbacks_for(:missing), []
  end

  def test_running_a_hook_with_no_callbacks_does_nothing(_args, assert)
    target = Chained.new
    target.run_callbacks(:missing, :payload)

    assert.equal! target.log, []
  end

  def test_reload_replaces_only_the_reregistered_hook(_args, assert)
    klass = Class.new(Recorder)
    generation = 1
    klass.define_singleton_method(:callback_generation) { generation }

    klass.set_callback(:a) { log << :old_a }
    klass.set_callback(:b) { log << :b }
    generation = 2
    klass.set_callback(:a) { log << :new_a }

    target = klass.new
    target.run_callbacks(:a, nil)
    target.run_callbacks(:b, nil)
    assert.equal! target.log, [ :new_a, :b ]
  end

  def test_define_callback_without_a_name_or_block_raises(_args, assert)
    error = capture_error(ArgumentError) { Class.new(Recorder).define_callback(:step) }

    assert.true! error, "expected ArgumentError"
    assert.equal! error.message, "on_step needs a method name or block"
  end

  def test_define_callback_resolves_method_names_when_called(_args, assert)
    target = LateNamed.new
    target.step(:payload)

    assert.equal! target.log, [ [ :advance, :payload ] ]
  end

  def test_zero_arg_block_ignores_the_argument(_args, assert)
    target = ZeroArgBlock.new
    target.step(:payload)

    assert.equal! target.log, [ :step ]
  end

  def test_subclass_definition_overrides_the_parents(_args, assert)
    overriding = Overriding.new
    overriding.step(nil)
    inheriting = Inheriting.new
    inheriting.step(nil)

    assert.equal! overriding.log, [ :child ]
    assert.equal! inheriting.log, [ :parent ]
  end

  def test_two_definitions_run_in_order(_args, assert)
    target = TwoCalls.new
    target.step(:payload)

    assert.equal! target.log, [ 1, :payload ]
  end

  def test_three_definitions_run_in_order(_args, assert)
    target = ThreeCalls.new
    target.step(:payload)

    assert.equal! target.log, [ [ :named, :payload ], :zero, :payload ]
  end

  def test_long_definition_chain_runs_in_order(_args, assert)
    target = FiveCalls.new
    target.step(nil)

    assert.equal! target.log, [ 1, 2, 3, 4, 5 ]
  end

  def test_reload_replaces_defined_callbacks(_args, assert)
    klass = Reloaded
    generation = 1
    klass.define_singleton_method(:callback_generation) { generation }

    klass.define_callback(:step) { log << :old }
    generation = 2
    klass.define_callback(:step) { log << :new }

    target = klass.new
    target.step(nil)
    assert.equal! target.log, [ :new ]
  end

  def test_anonymous_classes_can_define_callbacks(_args, assert)
    klass = Class.new(Recorder) do
      set_callback(:ping) { log << :ping }
      define_callback(:step) { |args| log << args }
    end
    target = klass.new
    target.run_callbacks(:ping, nil)
    target.step(:payload)

    assert.equal! target.log, [ :ping, :payload ]
  end
end
