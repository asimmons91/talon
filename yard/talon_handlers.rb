# YARD extensions for Talon's metaprogramming DSL. Loaded via .yardopts.

YARD::Tags::Library.define_tag("Yield Receiver", :yieldreceiver, :with_types)

# Documents methods defined in a +class_methods do ... end+ block (see
# Talon::Concern#class_methods) as instance methods of the concern's
# +ClassMethods+ module, which is how they exist at runtime.
class TalonClassMethodsHandler < YARD::Handlers::Ruby::Base
  handles method_call(:class_methods)
  namespace_only

  process do
    mod = register YARD::CodeObjects::ModuleObject.new(namespace, "ClassMethods")
    mod.docstring = "Methods added to the including class by {#{namespace.path}}." if mod.docstring.blank?
    parse_block(statement.block.last, namespace: mod)
  end
end
