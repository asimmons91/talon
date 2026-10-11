require "test/test_helper.rb"

class StateSpriteTests
  class Box
    include Talon::StateSprite

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

  class Body < Talon::Component
    include Talon::StateSprite
  end

  class Level < Talon::Scene; end

  def test_attributes_match_attr_sprite(_args, assert)
    readers = AttrSprite.instance_methods(false).select do |name|
      !name.to_s.end_with?("=") && AttrSprite.method_defined?(:"#{name}=")
    end

    assert.equal! Talon::StateSprite::ATTRIBUTES.sort, readers.sort
  end

  def test_attributes_default_to_nil(_args, assert)
    box = Box.new

    assert.true! Talon::StateSprite::ATTRIBUTES.all? { |name| box.send(name).nil? }, "every attribute should default to nil"
  end

  def test_attributes_are_stored_as_state(_args, assert)
    box = Box.new
    box.x = 10
    box.path = "sprites/box.png"

    assert.equal! box.store, { x: 10, path: "sprites/box.png" }
    assert.false! box.instance_variable_defined?(:@x), "attributes shouldn't be kept in ivars"
    assert.false! box.instance_variable_defined?(:@path), "attributes shouldn't be kept in ivars"
  end

  def test_attributes_can_be_set_from_keywords(_args, assert)
    box = Box.new(x: 1, y: 2, w: 3, h: 4, angle: 45)

    assert.equal! [ box.x, box.y, box.w, box.h, box.angle ], [ 1, 2, 3, 4, 45 ]
  end

  def test_is_a_sprite_primitive_without_being_an_attr_sprite(_args, assert)
    box = Box.new

    assert.equal! box.primitive_marker, :sprite
    assert.true! box.sprite.equal?(box), "sprite should return self"
    assert.false! box.is_a?(AttrSprite), "AttrSprite objects are rendered from ivars"
  end

  def test_x1_and_y1_alias_x_and_y(_args, assert)
    box = Box.new
    box.x1 = 5
    box.y1 = 6

    assert.equal! [ box.x, box.y ], [ 5, 6 ]
    assert.equal! [ box.x1, box.y1 ], [ 5, 6 ]
  end

  def test_rect_helpers_read_state(_args, assert)
    box = Box.new(x: 10, y: 20, w: 30, h: 40)

    assert.equal! [ box.left, box.right, box.bottom, box.top ], [ 10, 40, 20, 60 ]
    assert.true! box.intersect_rect?({ x: 35, y: 55, w: 10, h: 10 })
    assert.false! box.intersect_rect?({ x: 100, y: 100, w: 10, h: 10 })
  end

  def test_components_keep_sprite_attributes_in_args_state(args, assert)
    scene = Level.new
    scene.args = args
    go = Talon::GameObject.new(:player, scene: scene)
    go.add(Body, x: 7, w: 16)
    body = go[Body]
    body.y = 8

    assert.equal! [ body.x, body.y, body.w ], [ 7, 8, 16 ]
    assert.equal! args.state.components[:"StateSpriteTests::Level"][:player][:"StateSpriteTests::Body"],
                  { x: 7, y: 8, w: 16 }
  end
end
