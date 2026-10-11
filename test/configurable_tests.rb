require "test/test_helper.rb"

class ConfigurableTests
  class Settings
    include Talon::Configurable

    prop :speed, default: 2
    prop :label

    def initialize(**props)
      assign_props(props)
    end
  end

  class MoreSettings < Settings
    prop :color, default: :red
  end

  def test_props_use_their_defaults(_args, assert)
    settings = Settings.new

    assert.equal! settings.speed, 2
    assert.nil! settings.label
  end

  def test_keywords_override_defaults(_args, assert)
    settings = Settings.new(speed: 5, label: "fast")

    assert.equal! settings.speed, 5
    assert.equal! settings.label, "fast"
  end

  def test_props_are_writable(_args, assert)
    settings = Settings.new
    settings.speed = 9

    assert.equal! settings.speed, 9
  end

  def test_subclasses_inherit_props_without_changing_the_parent(_args, assert)
    settings = MoreSettings.new(speed: 3)

    assert.equal! [ settings.speed, settings.color ], [ 3, :red ]
    assert.equal! MoreSettings.prop_defaults, { speed: 2, label: nil, color: :red }
    assert.equal! Settings.prop_defaults, { speed: 2, label: nil }
  end

  def test_unknown_keywords_raise(_args, assert)
    one = capture_error(ArgumentError) { Settings.new(sped: 1) }
    two = capture_error(ArgumentError) { Settings.new(sped: 1, lable: "x") }

    assert.equal! one&.message, "unknown keyword: :sped"
    assert.equal! two&.message, "unknown keywords: :sped, :lable"
  end
end
