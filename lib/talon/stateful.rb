module Talon
  module Stateful
    extend Concern

    class_methods do
      def state(name, default: nil)
        state_defaults[name] = default
        define_method(name) { read_state(name) }
        define_method(:"#{name}=") { |value| state_store[name] = value }
      end

      # @return [Hash{Symbol => Object}]
      def state_defaults
        @state_defaults ||= superclass.respond_to?(:state_defaults) ? superclass.state_defaults : {}
      end
    end

    private

    # @param values [Hash{Symbol => Object}]
    # @return [Hash{Symbol => Object}]
    def extract_state(values)
      names = self.class.state_defaults.keys
      @state_init = values.select { |name, _| names.include?(name) }
      values.reject { |name, _| names.include?(name) }
    end

    # @return [Hash]
    def state_store
      raise NotImplementedError, "#{self.class} includes Stateful but doesn't define a state_store"
    end

    # @param name [Symbol]
    # @return [Hash{Symbol => Object}]
    def read_state(name)
      store = state_store
      return store[name] if store.key?(name)

      store[name] = (@state_init || {}).fetch(name) { self.class.state_defaults[name] }
    end
  end
end
