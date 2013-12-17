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

      new_url = ['beanstalk://beaneater', 'beaneater:11300']
      Beaneater.configuration.beanstalkd_url = new_url
      assert_equal new_url, BeanCounter.beanstalkd_url
      Beaneater.configuration.beanstalkd_url = original_url_beaneater


      new_url = 'beanstalk://bean_counter'
      BeanCounter.beanstalkd_url = new_url
      assert_equal [new_url], BeanCounter.beanstalkd_url
      BeanCounter.beanstalkd_url = original_url_bean_counter

      new_url = 'beanstalk://env'
      ENV['BEANSTALKD_URL'] = new_url
      assert_equal [new_url], BeanCounter.beanstalkd_url
      ENV['BEANSTALKD_URL'] = original_url_env
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


  context '::reset!' do

    setup do
      @tube_name = SecureRandom.uuid
      client.transmit("use #{@tube_name}")
      @message = SecureRandom.uuid
      client.transmit("watch #{@tube_name}")
      client.transmit('ignore default')
    end

    should 'remove all jobs from all tubes when not given a tube name' do
      jobs = []
      jobs << client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")[:id]
      timeout(1) do
        job_id = client.transmit('reserve')[:id]
        client.transmit("bury #{job_id} 0")
      end
      5.times do
        client.transmit("use #{SecureRandom.uuid}")
        jobs << client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")[:id]
      end
      client.transmit("use #{SecureRandom.uuid}")
      jobs << client.transmit("put 0 1024 120 #{@message.bytesize}\r\n#{@message}")[:id]

      BeanCounter.reset!
      jobs.each do |job_id|
        assert_raises(Beaneater::NotFoundError) do
          client.transmit("stats-job #{job_id}")
        end
      end
    end


    should 'only remove jobs from the specified tube when given a tube name' do
      jobs = []
      jobs << client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")[:id]
      timeout(1) do
        job_id = client.transmit('reserve')[:id]
        client.transmit("bury #{job_id} 0")
      end
      jobs << client.transmit("put 0 1024 120 #{@message.bytesize}\r\n#{@message}")[:id]

      client.transmit("use #{SecureRandom.uuid}")
      other_job_id = client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")[:id].to_i

      BeanCounter.reset!(@tube_name)
      jobs.each do |job_id|
        assert_raises(Beaneater::NotFoundError) do
          client.transmit("stats-job #{job_id}")
        end
      end
      assert_equal other_job_id, client.transmit("stats-job #{other_job_id}")[:body]['id']
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
