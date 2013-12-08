require 'bean_counter/spec'

if defined?(RSpec)
  RSpec.configuration.include(BeanCounter::Spec)
end
