require 'coveralls'
Coveralls.wear_merged!

lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'rspec'
require 'bean_counter'

BeanCounter.beanstalkd_url = 'beanstalk://localhost'
