require 'debugger'
require 'coveralls'
Coveralls.wear_merged!

lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'test/unit'
require 'mocha/setup'
require 'minitest/autorun'
require 'minitest/should'
require 'bean_counter'
require 'bean_counter/mini_test'
require 'securerandom'

# Open TCP connection with beanstalkd server prevents
# JRuby timeout from killing thread. Has some weird
# side effects, but allows Timeout#timeout to work
if RUBY_PLATFORM == 'java'
  module Timeout
    def timeout(sec, klass=nil)
      return yield(sec) if sec == nil or sec.zero?
      thread = Thread.new { yield(sec) }

      if thread.join(sec).nil?
        java_thread = JRuby.reference(thread)
        thread.kill
        java_thread.native_thread.interrupt
        thread.join(0.15)
        raise (klass || Error), 'execution expired'
      else
        thread.value
      end
    end
  end
end

BeanCounter.beanstalkd_url = 'beanstalk://localhost'

class BeanCounter::TestCase < MiniTest::Should::TestCase

  include Timeout


  def self.create_test_gemerald_beanstalks
    return if class_variable_defined?(:@@gemerald_strategy)
    @@gemerald_addrs ||= ['127.0.0.1:11400', '127.0.0.1:11401']
    previous_urls = BeanCounter.beanstalkd_url
    BeanCounter.beanstalkd_url = @@gemerald_addrs
    @@gemerald_strategy = BeanCounter::Strategy::GemeraldBeanstalkStrategy.new
    @@gemerald_beanstalks = @@gemerald_strategy.send(:beanstalks)
    clients_by_address = @@gemerald_beanstalks.map do |beanstalk|
      [beanstalk.address, beanstalk.direct_connection_client]
    end
    @@gemerald_clients = Hash[clients_by_address]
    BeanCounter.beanstalkd_url = previous_urls
  end


  def client
    return @client ||= Beaneater::Connection.new('localhost:11300')
  end


  def gemerald_client(gemerald_addr = nil)
    self.class.create_test_gemerald_beanstalks
    gemerald_addr ||= @@gemerald_addrs.first
    return @@gemerald_clients[gemerald_addr]
  end

end


class BeanCounter::KnownStrategy < BeanCounter::Strategy
end
