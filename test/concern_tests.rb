require "test/test_helper.rb"

class ConcernTests
  module Greeting
    extend Talon::Concern

    included do
      @greeting_included = (@greeting_included || 0) + 1
    end

    class_methods do
      def greeting
        "hello from #{name}"
      end
    end

    def greet
      "hi"
    end
  end

  module Polite
    extend Talon::Concern
    include Greeting

    included do
      @polite_host = self
    end

    class_methods do
      def polite?
        true
      end
    end
  end

  module Loud
    extend Talon::Concern

    prepended do
      @loud_prepended = true
    end

    class_methods do
      def shout
        "#{super.upcase}!"
      end
    end

    def speak
      "#{super.upcase}!"
    end
  end

  class Host
    include Greeting
  end

  class PoliteHost
    include Polite
  end

  class Speaker
    def self.shout
      "hey"
    end

    def speak
      "hello"
    end

    prepend Loud
  end

  def test_class_methods_are_extended_onto_the_host(_args, assert)
    assert.equal! Host.greeting, "hello from ConcernTests::Host"
    assert.equal! Host.new.greet, "hi"
  end

  def test_included_block_runs_in_the_host(_args, assert)
    assert.equal! Host.instance_variable_get(:@greeting_included), 1
  end

  def test_including_twice_runs_the_included_block_once(_args, assert)
    klass = Class.new do
      include ConcernTests::Greeting
      include ConcernTests::Greeting
    end

    assert.equal! klass.instance_variable_get(:@greeting_included), 1
  end

  def test_dependencies_are_included_into_the_final_host(_args, assert)
    assert.true! PoliteHost.include?(Greeting), "dependency should be included into the host"
    assert.equal! PoliteHost.greeting, "hello from ConcernTests::PoliteHost"
    assert.true! PoliteHost.polite?
    assert.equal! PoliteHost.instance_variable_get(:@greeting_included), 1
    assert.equal! PoliteHost.instance_variable_get(:@polite_host), PoliteHost
  end

  def test_concern_including_a_concern_defers_it(_args, assert)
    assert.false! Polite.include?(Greeting), "dependency shouldn't be included into the concern itself"
    assert.nil! Polite.instance_variable_get(:@greeting_included)
  end

  def test_prepend_wraps_instance_and_class_methods(_args, assert)
    assert.equal! Speaker.new.speak, "HELLO!"
    assert.equal! Speaker.shout, "HEY!"
    assert.true! Speaker.instance_variable_get(:@loud_prepended)
  end

  def test_class_methods_reopens_the_same_module(_args, assert)
    mod = Module.new do
      extend Talon::Concern

      class_methods do
        def one
          1
        end
      end

      class_methods do
        def two
          2
        end
      end
    end
    klass = Class.new { include mod }

    assert.equal! [ klass.one, klass.two ], [ 1, 2 ]
  end
end
