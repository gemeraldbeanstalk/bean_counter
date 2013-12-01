require 'test_helper'
require 'securerandom'

class StalkClimberStrategyTest < BeanCounter::TestCase

  setup do
    @strategy = BeanCounter::Strategy::StalkClimberStrategy.new
  end

  context '#jobs' do

    should 'implement #jobs' do
      assert @strategy.respond_to?(:jobs)
      assert_kind_of Enumerable, @strategy.jobs
      begin
        @strategy.jobs.each do
          break
        end
      rescue NotImplementedError
        raise 'Expected subclass of Strategy, BeanCounter::Strategy::StalkClimberStrategy, to provide #jobs enumerator'
      end
    end

  end


  context '#collect_new_jobs' do

    should 'raise ArgumentError unless block given' do
      assert_raises(ArgumentError) do
        @strategy.collect_new_jobs
      end
    end


    should 'return empty array if no new jobs enqueued' do
      new_jobs = @strategy.collect_new_jobs {}
      assert_equal [], new_jobs
    end


    should 'return only jobs enqueued during block execution' do
      @tube_name = SecureRandom.uuid
      client.transmit("use #{@tube_name}")
      client.transmit("watch #{@tube_name}")
      client.transmit('ignore default')
      message = SecureRandom.uuid
      all_jobs = []
      all_jobs << client.transmit("put 0 0 120 #{message.bytesize}\r\n#{message}")[:id].to_i

      jobs = []
      new_jobs = @strategy.collect_new_jobs do
        5.times do
          message = SecureRandom.uuid
          job_id = client.transmit("put 0 0 120 #{message.bytesize}\r\n#{message}")[:id].to_i
          jobs << job_id
          all_jobs << job_id
        end
      end

      message = SecureRandom.uuid
      all_jobs << client.transmit("put 0 0 120 #{message.bytesize}\r\n#{message}")[:id].to_i
      assert_equal new_jobs.map(&:id), jobs
      all_jobs.each { |job_id| client.transmit("delete #{job_id}") }
    end

  end


  context '#delete_job' do

    should 'delete the provided job' do
      message = SecureRandom.uuid
      job = client.transmit("put 0 0 120 #{message.bytesize}\r\n#{message}")
      strategy_job = StalkClimber::Job.new(job)
      @strategy.delete_job(strategy_job)
      refute strategy_job.exists?
      assert_raises(Beaneater::NotFoundError) do
        client.transmit("stats-job #{job[:id]}")
      end
    end


    should 'not complain if job already deleted' do
      message = SecureRandom.uuid
      job = client.transmit("put 0 0 120 #{message.bytesize}\r\n#{message}")
      strategy_job = StalkClimber::Job.new(job)
      client.transmit("delete #{job[:id]}")
      @strategy.delete_job(strategy_job)
      refute strategy_job.exists?
    end

  end

  context '#job_matches?' do

    setup do
      @tube_name = SecureRandom.uuid
      @message = SecureRandom.uuid
      client.transmit("use #{@tube_name}")
      client.transmit("watch #{@tube_name}")
      client.transmit('ignore default')
      @job = client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
      @strategy_job = StalkClimber::Job.new(@job)
      # Update job state so everything is cached
      @strategy_job.age
      @strategy_job.body
    end


    teardown do
      begin
        client.transmit("delete #{@job[:id]}")
      rescue Beaneater::NotFoundError
      end
    end


    should 'match string fields using string or regex' do
      job_stats = client.transmit("stats-job #{@job[:id]}")[:body]
      {
        :body => @message,
        :state => job_stats['state'],
        :tube => @tube_name,
      }.each_pair do |key, value|
        assert @strategy.job_matches?(@strategy_job, key => value)
        assert @strategy.job_matches?(@strategy_job, key => %r[#{value[2, 3]}])
        refute @strategy.job_matches?(@strategy_job, key => 'foobar')
        refute @strategy.job_matches?(@strategy_job, key => /foobar/)
      end
    end


    should 'match integer fields using integer or range' do
      job_stats = client.transmit("stats-job #{@job[:id]}")[:body]
      verify_job_attrs({
        :age => job_stats['age'],
        :buries => job_stats['buries'],
        :delay => job_stats['delay'],
        :id => @job[:id].to_i,
        :kicks => job_stats['kicks'],
        :pri => job_stats['pri'],
        :releases => job_stats['releases'],
        :reserves => job_stats['reserves'],
        :'time-left' => job_stats['time-left'],
        :timeouts => job_stats['timeouts'],
        :ttr => job_stats['ttr'],
      })
    end


    should 'match integer fields using integer or range (with more stubs)' do
      job_attrs = {
        :age => 100,
        :buries => 101,
        :delay => 102,
        :id => 12345,
        :kicks => 103,
        :pri => 104,
        :releases => 105,
        :reserves => 106,
        :timeouts => 108,
        :ttr => 109,
      }
      # Mocha can't handle time-left :(
      @strategy_job.instance_eval { define_singleton_method(:'time-left') { return 107 } }
      job_attrs.each_pair { |key, value| @strategy_job.expects(key).times(8).returns(value) }
      @strategy_job.expects(:exists?).times(40).returns(true)
      verify_job_attrs(job_attrs)
    end


    should 'not try to match on non-matachable attributes' do
      # Called once to refresh job state before checking match
      @strategy_job.expects(:exists?).once.returns(true)

      # Would be called but skipped because of expectation on exists?
      @strategy_job.expects(:connection).never
      @strategy_job.expects(:stats).never

      # Should never be called
      @strategy_job.expects(:delete).never

      assert @strategy.job_matches?(@strategy_job, {
        :body => @message,
        :connection => 'foo',
        :delete => 'bar',
        :exists? => 'baz',
        :stats => 'boom',
      })
    end


    should 'not match job deleted after it was cached' do
      client.transmit("delete #{@job[:id]}")
      refute @strategy.job_matches?(@strategy_job, :body => @message)
    end


    should 'match against updated job stats' do
      pri = 1024
      delay = 2048
      job = nil
      timeout(1) do
        job = client.transmit('reserve')
      end
      client.transmit("release #{job[:id]} #{pri} #{delay}")
      assert @strategy.job_matches?(@strategy_job, {
        :body => @message,
        :delay => (delay - 2)..delay,
        :pri => pri,
        :state => 'delayed',
      })
      refute @strategy.job_matches?(@strategy_job, {
        :body => @message,
        :delay => 0,
        :pri => 0,
      })
    end

  end


  context '#pretty_print_job' do

    should 'return expected text representation of job' do
      job_body = SecureRandom.uuid
      stats_body = {
        'age' => age = 3,
        'body' => job_body, # Will be ignored during job init
        'buries' => buries = 0,
        'delay' => delay = 0,
        'id' => id = 4412,
        'kicks' => kicks = 0,
        'pri' => pri = 4294967295,
        'releases' => releases = 0,
        'reserves' => reserves = 0,
        'state' => state = 'ready',
        'time-left' => time_left = 0,
        'timeouts' => timeouts = 0,
        'ttr'  => ttr = 300,
        'tube' => tube = 'default',
      }
      stats_response = {
        :body => stats_body,
        :connection => client,
        :id => 149,
        :status => 'OK',
      }
      job = StalkClimber::Job.new(stats_response)
      job.instance_variable_set(:@body, job_body)
      job.connection.expects(:transmit).once.returns(stats_response)
      expected = %W[
        "age"=>#{age} "body"=>"#{job_body}" "buries"=>#{buries} "connection"=>#{client.to_s}
        "delay"=>#{delay} "id"=>#{id} "kicks"=>#{kicks} "pri"=>#{pri} "releases"=>#{releases}
        "reserves"=>#{reserves} "state"=>"#{state}" "time-left"=>#{time_left}
        "timeouts"=>#{timeouts} "ttr"=>#{ttr} "tube"=>"#{tube}"
      ].join(', ')
      assert_equal "{#{expected}}", @strategy.pretty_print_job(job)
    end

  end


  context '#test_tube' do

    should 'return default test tube unless set otherwise' do
      assert_equal BeanCounter::Strategy::StalkClimberStrategy::TEST_TUBE, @strategy.send(:test_tube)
      @strategy.test_tube = new_tube = 'bean_counter_stalk_climber_test_new'
      assert_equal new_tube, @strategy.send(:test_tube)
      @strategy.test_tube = nil
      assert_equal BeanCounter::Strategy::StalkClimberStrategy::TEST_TUBE, @strategy.send(:test_tube)
    end

  end


  def verify_job_attrs(job_attrs)
    job_attrs.each_pair do |key, value|
      sanitized_key = key.to_s.gsub(/-/, '_')
      assert @strategy.job_matches?(@strategy_job, key => value), "Expected #{key} (#{@strategy_job.send(sanitized_key)}) to match #{value}"
      assert @strategy.job_matches?(@strategy_job, key => (value - 5)..(value + 1)), "Expected #{key} (#{@strategy_job.send(sanitized_key)}) to match #{value} +/-5"
      refute @strategy.job_matches?(@strategy_job, key => value - 1),  "Expected #{key} (#{@strategy_job.send(sanitized_key)}) to not match #{value}"
      refute @strategy.job_matches?(@strategy_job, key => (value + 100)..(value + 200)),  "Expected #{key} (#{@strategy_job.send(sanitized_key)}) to not match #{value + 100}..#{value + 200}"
    end
  end

end
