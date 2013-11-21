require 'coveralls'
Coveralls.wear!

lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'test/unit'
require 'mocha/setup'
require 'minitest/autorun'
require 'minitest/should'
require 'bean_counter'
BeanCounter.beanstalkd_url = 'beanstalk://localhost'


class BeanCounter::TestCase < MiniTest::Should::TestCase

  def client
    return @client ||= Beaneater::Connection.new('localhost:11300')
  end

end


class BeanCounter::KnownStrategy < BeanCounter::Strategy
end
