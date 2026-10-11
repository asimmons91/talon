module Talon
  # A named entity in a {Scene}, made up of {Component}s. Game objects are
  # usually created with {Scene#spawn}.
  #
  # The name keys the object's {Stateful} values (and those of its
  # components) in +args.state+, so it should be unique within its scene and
  # stable across reloads.
  class GameObject
    attr_dr

    include Stateful

    # @return [Scene, nil] the scene this object belongs to
    attr_accessor :scene

    # @return [Symbol, String] the object's name, unique within its scene
    attr_reader :name

    # @return [Array<Symbol>] labels for grouping and lookup
    attr_reader :tags

    # @param value [Boolean] whether the object and its components should
    #   update and draw
    # @return [Boolean]
    attr_writer :active

    # @param name [Symbol, String] unique name within the scene
    # @param scene [Scene, nil] the owning scene
    # @param tags [Array<Symbol>] labels for grouping and lookup
    # @param state_values [Hash{Symbol => Object}] initial values for
    #   declared state
    # @yieldparam game_object [GameObject] the new object, for adding components
    # @raise [ArgumentError] if a keyword isn't a declared state value
    def initialize(name, scene: nil, tags: [], **state_values)
      assign_state(state_values)

      @name = name
      @scene = scene
      @tags = tags
      @active = true

      @components = {}
      self.args = scene.args if scene

      # @type [Array<Component>]
      @fresh = []

      # @type [Array<Component>]
      @updaters = []

      # @type [Array<Component>]
      @drawers = []

      yield self if block_given?
    end

    # Sets the DragonRuby args for this object and its components.
    #
    # @param value [GTK::Args]
    # @return [void]
    def args=(value)
      super
      @components.each_value { |c| c.args = value }
    end

    # @return [Boolean] whether the object and its components update and draw
    def active?
      @active
    end

    # @param tag [Symbol]
    # @return [Boolean] whether {#tags} includes +tag+
    def tagged?(tag)
      @tags.include?(tag)
    end

    # Builds a component and attaches it to this object.
    #
    # @param klass [Class<Component>]
    # @param props [Hash{Symbol => Object}] passed to the component's constructor
    # @return [self]
    def add(klass, **props)
      self << klass.new(**props)
    end

    # Attaches an already-built component to this object. Its +on_start+
    # callbacks run on the object's next {#update}.
    #
    # @param component [Component]
    # @return [self]
    def <<(component)
      component.go = self
      component.args = args
      @components[component.class] = component
      @fresh << component
      @updaters << component if component.respond_to?(:update)
      @drawers << component if component.respond_to?(:draw)
      self
    end

    # Looks up an attached component by class, falling back to the first one
    # that is an instance of a subclass.
    #
    # @param klass [Class<Component>]
    # @return [Component, nil]
    def [](klass)
      @components[klass] || @components.values.find { |c| c.is_a?(klass) }
    end

    # Runs +on_start+ for newly attached components, then updates every
    # enabled component. Does nothing while the object is inactive. Called by
    # {Scene#tick}.
    #
    # @return [void]
    def update
      return unless active?

      @fresh.each { |c| c.run_callbacks(:start, args) }
      @fresh.clear

      @updaters.each { |c| c.update(args) if c.enabled? }
    end

    # Draws every enabled component. Does nothing while the object is
    # inactive. Called by {Scene#tick}.
    #
    # @return [void]
    def draw
      return unless active?

      @drawers.each { |c| c.draw(args) if c.enabled? }
    end

    # Queues this object for removal from its scene at the end of the
    # current tick.
    #
    # @return [void]
    # @see Scene#destroy
    def destroy
      scene.destroy(self)
    end

    # Runs every component's +on_destroy+ callbacks. Called by the scene when
    # the object is removed; use {#destroy} to remove an object.
    #
    # @return [void]
    def teardown
      @components.each_value { |c| c.run_callbacks(:destroy, args) }
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
