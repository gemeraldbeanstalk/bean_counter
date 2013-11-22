require 'test_helper'

class CoreTest < BeanCounter::TestCase

  context '::beanstalkd_url' do

    should 'check BeanCounter, then ENV, then Beaneater for beanstalkd_url and raise an error if no url found' do
      original_url_bean_counter = BeanCounter.beanstalkd_url
      original_url_env = ENV['BEANSTALKD_URL']
      original_url_beaneater = Beaneater.configuration.beanstalkd_url

      BeanCounter.beanstalkd_url = nil
      Beaneater.configuration.beanstalkd_url = nil
      ENV['BEANSTALKD_URL'] = nil

      assert_raises(RuntimeError) do
        BeanCounter.beanstalkd_url
      end

      new_url = 'beanstalk://beaneater'
      Beaneater.configuration.beanstalkd_url = new_url
      assert_equal new_url, BeanCounter.beanstalkd_url
      Beaneater.configuration.beanstalkd_url = original_url_beaneater

      # Env beanstalkd_url is always turned into an array
      new_url = 'beanstalk://env'
      ENV['BEANSTALKD_URL'] = new_url
      assert_equal [new_url], BeanCounter.beanstalkd_url
      ENV['BEANSTALKD_URL'] = original_url_env

      new_url = 'beanstalk://bean_counter'
      BeanCounter.beanstalkd_url = new_url
      assert_equal new_url, BeanCounter.beanstalkd_url
      BeanCounter.beanstalkd_url = original_url_bean_counter
    end

  end


  context '::default_strategy' do

    should 'return materialized version of DEFAULT_STRATEGY' do
      assert_equal(
        BeanCounter::Strategy.materialize_strategy(BeanCounter::DEFAULT_STRATEGY),
        BeanCounter.default_strategy
      )
    end

  end


  context '::strategies' do

    should 'return strategies from BeanCounter::Strategy' do
      BeanCounter::Strategy.expects(:strategies).once.returns(:return_value)
      assert_equal :return_value, BeanCounter.strategies
    end

  end


  context '::strategy=' do

    should 'set instance variable when given valid strategy' do
      original_strategy = BeanCounter.strategy.class
      [
        'BeanCounter::KnownStrategy',
        :'BeanCounter::KnownStrategy',
        BeanCounter::KnownStrategy
      ].each do |good_strategy|
        BeanCounter.strategy = BeanCounter::KnownStrategy
        assert_kind_of BeanCounter::KnownStrategy, BeanCounter.strategy
        BeanCounter.strategy = BeanCounter::Strategy
      end
      BeanCounter.strategy = original_strategy
    end


    should 'accept nil for strategy' do
      original_strategy = BeanCounter.strategy.class
      BeanCounter.strategy = nil
      assert_nil BeanCounter.instance_variable_get(:@strategy)
      BeanCounter.strategy = original_strategy
    end

  end


  context '::strategy' do

    should 'default to BeanCounter.default_strategy' do
      BeanCounter.strategy = nil
      assert_kind_of BeanCounter.default_strategy, BeanCounter.strategy
    end

  end

end
