module Talon
  class Game
    attr_dr

    include Stateful

    def initialize(scene, **state_values)
      extract_state(state_values)

      @next_scene = scene
    end

    def change_scene(scene)
      @next_scene = scene
    end

    def tick
      if @next_scene
        @scene.teardown if @scene
        @scene = @next_scene
        @next_scene = nil
        @scene.game = self
        @scene.run_callbacks(:enter)
      end

      @scene.tick
    end

    private

    def state_store
      args.state.game ||= {}
    end
  end
end
