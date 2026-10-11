module Talon
  module Concern
    # @param base [Module]
    def self.extended(base)
      base.instance_variable_set(:@_dependencies, [])
    end


    # @param base [Module]
    # @return [Boolean]
    def append_features(base)
      if base.instance_variable_defined?(:@_dependencies)
        base.instance_variable_get(:@_dependencies) << self
        return false
      end

      return false if base.ancestors.include?(self)

      @_dependencies.each { |dependency| base.include(dependency) }
      super

      base.extend(const_get(:ClassMethods)) if const_defined?(:ClassMethods, false)
      base.class_eval(&@_included_block) if @_included_block
      true
    end

    # @param base [Module]
    # @return [Boolean]
    def prepend_features(base)
      if base.instance_variable_defined?(:@_dependencies)
        base.instance_variable_get(:@_dependencies).unshift(self)
        return false
      end

      return false if base.ancestors.include?(self)

      @_dependencies.each { |dependency| base.prepend(dependency) }
      super

      base.singleton_class.prepend(const_get(:ClassMethods)) if const_defined?(:ClassMethods, false)
      base.class_eval(&@_prepended_block) if @_prepended_block
      true
    end

    # @param base [Module, nil]
    # @yieldreceiver [Class]
    # @return [void]
    def included(base = nil, &block)
      return super(base) unless block

      @_included_block = block
    end

    # @param base [Module, nil]
    # @yieldreceiver [Class]
    # @return [void]
    def prepended(base = nil, &block)
      return super(base) unless block

      @_prepended_block = block
    end

    # @yieldreceiver [Module]
    # @return [void]
    def class_methods(&block)
      mod = const_defined?(:ClassMethods, false) ? const_get(:ClassMethods) : const_set(:ClassMethods, Module.new)
      mod.module_eval(&block)
    end
  end
end
