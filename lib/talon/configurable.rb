module Talon
  module Configurable
    extend Concern

    class_methods do
      def prop(name, default: nil)
        attr_accessor name
        prop_defaults[name] = default
      end

      def prop_defaults
        @prop_defaults ||= superclass.respond_to?(:prop_defaults) ? superclass.prop_defaults.dup : {}
      end
    end

    private

    def assign_props(values)
      self.class.prop_defaults.merge(values).each { |name, value| send(:"#{name}=", value) }
    end
  end
end
