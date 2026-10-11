module Talon
  class Scene
    attr_dr

    include Enumerable
    include Stateful
    include Callbacks

    attr_accessor :game

    def initialize(**state_values)
      extract_state(state_values)

      # @type [Array<GameObject>]
      @game_objects = []

      # @type [Array<GameObject>]
      @incoming = []

      # @type [Array<GameObject>]
      @outgoing = []
    end

    def spawn(name, *prefabs, **attrs, &block)
      game_object = GameObject.new(name, scene: self, **attrs) do |g|
        prefabs.each { |prefab| prefab.call(g) }
        block&.call(g)
      end

      @incoming << game_object
      game_object
    end

    def destroy(game_object)
      @outgoing << game_object
    end

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

    def teardown
      run_callbacks(:exit)

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
