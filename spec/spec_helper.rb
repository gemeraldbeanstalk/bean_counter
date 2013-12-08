require 'coveralls'
Coveralls.wear_merged!

lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'rspec'
require 'mocha/api'
require 'bean_counter'
require 'bean_counter/spec/auto'

BeanCounter.beanstalkd_url = 'beanstalk://localhost'


def client
  return @client ||= Beaneater::Connection.new('localhost:11300')
end
