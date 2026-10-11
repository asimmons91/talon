module Talon
  class Componet
    attr_dr

    include Configurable
    include Stateful
    include Callbacks

    # @return [GameObject]
    attr_accessor :go

    attr_writer :enabled

    def self.on_start(*method_names, &block)
      set_callback(:start, *method_names, &block)
    end

    def self.on_destroy(*method_names, &block)
      set_callback(:destroy, *method_names, &block)
    end

    def self.on_update(*method_names, &block)
      define_callback(:update, *method_names, &block)
    end

    def self.on_draw(*method_names, &block)
      define_callback(:draw, *method_names, &block)
    end

    def initialize(**props)
      @enabled = true
      assign_props(extract_state(props))
    end

    def enabled?
      @enabled
    end

    def scene
      go.scene
    end

    private

    def state_store
      raise "#{self.class} state read before it was attached to as scene" unless go&.scene

      scenes = args.state.components ||= {}
      objects = scenes[go.scene.class.name.to_sym] ||= {}
      components = objects[go.name] ||= {}
      components[self.class.name.to_sym] ||= {}
    end
  end
end
