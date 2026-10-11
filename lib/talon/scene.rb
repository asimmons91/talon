module Talon
  # A collection of {GameObject}s that make up one screen or level of a
  # {Game}. Subclass it to declare scene state and +:enter+ / +:exit+
  # callbacks.
  #
  # Objects spawned or destroyed during a tick are added or removed at a tick
  # boundary, so iterating the scene is always safe.
  #
  # @example
  #   class Level < Talon::Scene
  #     state :score, default: 0
  #
  #     set_callback(:enter) do
  #       spawn(:player) { |go| go.add(Mover) }
  #     end
  #   end
  class Scene
    attr_dr

    include Enumerable
    include Stateful
    include Callbacks

    # @return [Game, nil] the game running this scene, set when it is entered
    attr_accessor :game

    # @param state_values [Hash{Symbol => Object}] initial values for
    #   declared state
    # @raise [ArgumentError] if a keyword isn't a declared state value
    def initialize(**state_values)
      assign_state(state_values)

      # @type [Array<GameObject>]
      @game_objects = []

      # @type [Array<GameObject>]
      @incoming = []

      # @type [Array<GameObject>]
      @outgoing = []
    end

    # Sets the DragonRuby args for this scene and its game objects. Called by
    # {Game#tick}.
    #
    # @param value [GTK::Args]
    # @return [void]
    def args=(value)
      super
      @game_objects.each { |e| e.args = value }
      @incoming.each { |e| e.args = value }
    end

    # Iterates the game objects in the scene, not including those spawned
    # since the last {#tick}.
    #
    # @yieldparam game_object [GameObject]
    # @return [self, Enumerator]
    def each(&block)
      return enum_for(:each) unless block

      @game_objects.each(&block)
      self
    end

    # Creates a game object in this scene. It starts updating on the next
    # {#tick}.
    #
    # @param name [Symbol, String] unique name within the scene
    # @param prefabs [Array<#call>] objects called with the new game object,
    #   in order, before the block, typically to add a reusable set of
    #   components
    # @param attrs [Hash{Symbol => Object}] passed to {GameObject#initialize}
    #   (+tags:+ and state values)
    # @yieldparam game_object [GameObject] the new object, for adding components
    # @return [GameObject]
    # @raise [ArgumentError] if an attribute isn't +tags:+ or declared state
    def spawn(name, *prefabs, **attrs, &block)
      game_object = GameObject.new(name, scene: self, **attrs) do |g|
        prefabs.each { |prefab| prefab.call(g) }
        block&.call(g)
      end

      @incoming << game_object
      game_object
    end

    # Queues a game object for removal at the end of the current tick, when
    # its components' +on_destroy+ callbacks run.
    #
    # @param game_object [GameObject]
    # @return [void]
    def destroy(game_object)
      @outgoing << game_object
    end

    # Advances the scene one frame: adds newly spawned objects, updates and
    # then draws every object, and removes destroyed objects. Called by
    # {Game#tick}.
    #
    # @return [void]
    def tick
      @game_objects.concat(@incoming)
      @incoming.clear

      each { |e| e.update }
      each { |e| e.draw }

      return if @outgoing.empty?

      @outgoing.each { |e| e.teardown }
      @game_objects -= @outgoing
      @incoming -= @outgoing
      @outgoing.clear
    end

    # Runs the scene's +:exit+ callbacks, tears down every game object, and
    # empties the scene. Called by {Game#tick} when switching scenes.
    #
    # @return [void]
    def teardown
      run_callbacks(:exit, args)

      (@game_objects + @incoming).each { |e| e.teardown }
      @game_objects.clear
      @incoming.clear
      @outgoing.clear
    end

    private

    def state_store
      scenes = args.state.scenes ||= {}
      scenes[self.class.name.to_sym] ||= {}
    end
  end
end
