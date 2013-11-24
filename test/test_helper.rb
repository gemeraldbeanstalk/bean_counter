require 'coveralls'
Coveralls.wear!

lib = File.expand_path('../../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'test/unit'
require 'mocha/setup'
require 'minitest/autorun'
require 'minitest/should'
require 'bean_counter'

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


  def client
    return @client ||= Beaneater::Connection.new('localhost:11300')
  end

end


class BeanCounter::KnownStrategy < BeanCounter::Strategy
end
