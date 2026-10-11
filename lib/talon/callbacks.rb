module Talon
  module Callbacks
    extend Concern

    class_methods do
      def set_callback(hook, *method_names, &block)
        chain = own_callbacks[hook] ||= {}
        method_names.each { |name| chain[name] = [ name, true ] }
        chain[self] = define_hook_method(hook, block) if block
      end

      def define_callback(hook, *method_names, &block)
        raise ArgumentError, "on_#{hook} needs a method name or block" if method_names.empty? && !block
        return define_method(hook, &block) if method_names.empty? && block.arity != 0

        calls = method_names.map { |m| [ m, true ] }
        calls << define_hook_method(hook, block) if block

        if calls.size == 1
          target, takes_args = calls.first
          if takes_args
            define_method(hook) { |args| send(target, args) }
          else
            define_method(hook) { |_args| send(target) }
          end
        else
          define_method(hook) do |args|
            calls.each { |m, takes| takes ? send(m, args): send(m) }
          end
        end
      end

      def callbacks_for(hook)
        inherited = superclass.respond_to?(:callbacks_for) ? superclass.callbacks_for(hook) : []
        inherited + (own_callbacks[hook] || {}).values
      end

      private

      def own_callbacks
        @own_callbacks ||= {}
      end

      def define_hook_method(hook, block)
        method_name = :"#{name}#on_#{hook}"
        define_method(method_name, &block)
        private method_name
        [ method_name, block.arity != 0 ]
      end
    end

    def run_callbacks(hook, args)
      self.class.callbacks_for(hook).each do |method_name, takes_args|
        takes_args ? send(method_name, args) : send(method_name)
      end
    end
  end
end
