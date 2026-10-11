require "lib/talon.rb"

# Runs the block and returns the exception it raised, or nil if it didn't
# raise. DragonRuby's assert has no equivalent of +assert_raises+.
#
# @param klass [Class<Exception>] the exception class to rescue
# @return [Exception, nil]
def capture_error(klass = StandardError)
  yield
  nil
rescue klass => e
  e
end
