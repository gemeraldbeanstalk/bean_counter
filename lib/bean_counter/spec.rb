require 'bean_counter/spec_matchers'

if defined?(RSpec)
  RSpec.configuration.include(BeanCounter::SpecMatchers)
end
