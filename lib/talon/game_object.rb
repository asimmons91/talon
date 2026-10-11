module Talon
  class GameObject
    attr_dr

    include Stateful

    attr_accessor :scene

    attr_reader :name

    attr_reader :tags

    attr_writer :active

    def initialize(name, scene: nil, tags: [], **kwargs)
      @name = name
      @scene = scene
      @tags = tags
      @active = true

      @components = {}

      # @type [Array<Component>]
      @fresh = []

      # @type [Array<Component>]
      @updaters = []

      # @type [Array<Component>]
      @drawers = []

      yield self if block_given?
    end

    def active?
      @active
    end

    def tagged?(tag)
      @tags.include?(tag)
    end

    def add(klass, **props)
      self << klass.new(**props)
    end

    def <<(component)
      component.go = self
      @components[component.class]
      @fresh << component
      @updaters << component if component.respond_to?(:update)
      @drawers << component if component.respond_to?(:draw)
      self
    end

    def [](klass)
      @components[klass] || @components.values.find { |c| c.is_a?(klass) }
    end

    def update
      return unless active?

      @fresh.each { |c| c.run_callback(:start) }
      @fresh.clear

      @updaters.each { |c| c.update if c.enabled? }
    end

    def draw
      return unless active?

      @drawers.each { |c| c.draw if c.enabled? }
    end

    def destroy
      scene.destroy(self)
    end

    def teardown
      @components.each_value { |c| c.run_callback(:destroy) }
    end

    private

    def state_store
      raise "#{name.inspect} state read before it was added to a scene" unless scene

      scenes = args.state.objects ||= {}
      objects = scenes[scene.class.name.to_sym] ||= {}
      objects[name] ||= {}
    end
  end
end
