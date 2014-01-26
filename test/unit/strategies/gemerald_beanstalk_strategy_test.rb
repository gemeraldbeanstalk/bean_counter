require 'test_helper'
require 'securerandom'

class GemeraldBeanstalkStrategyTest < BeanCounter::TestCase

  GemeraldBeanstalkStrategy = BeanCounter::Strategy::GemeraldBeanstalkStrategy

  context 'BeanCounter::Strategy::GemeraldBeanstalkStrategy' do

    should 'be a known_strategy' do
      BeanCounter::Strategy.known_strategy?(BeanCounter::Strategy::GemeraldBeanstalkStrategy)
      BeanCounter::Strategy.known_strategy?(GemeraldBeanstalkStrategy)
    end

  end


  %w[jobs tubes].each do |enumerator|
    context "##{enumerator} mocked behaviors" do

      enumerator_singular = enumerator[0, enumerator.length - 1]

      should "delegate to #{enumerator_singular}_enumerator returning an Enumerator" do
        BeanCounter.expects(:beanstalkd_url).returns([])
        @strategy = BeanCounter::Strategy::GemeraldBeanstalkStrategy.new
        @strategy.expects(enumerator).returns([:foo].to_enum)
        enum = @strategy.send(enumerator)
        assert_kind_of Enumerator, enum
        assert_equal :foo, enum.first
      end

    end

  end


  context 'gemerald_beanstalk config' do

    should 'load gemerald_beanstalk introspection plugin' do
      begin
        included = GemeraldBeanstalk::Beanstalk.included_modules.include?(GemeraldBeanstalk::Plugin::Introspection)
      rescue NameError => e
        raise e unless e.message == 'uninitialized constant GemeraldBeanstalk::Plugin::Introspection'
        included = false
      end
      assert included, 'Expected GemeraldBeanstalk::Plugin::Introspection to be loaded'
    end

  end


  context '#parse_url' do

    setup do
      BeanCounter.expects(:beanstalkd_url).returns([])
      @strategy = BeanCounter::Strategy::GemeraldBeanstalkStrategy.new
    end


    ['', 'beanstalk://'].each do |uri_scheme|
      context uri_scheme == '' ? 'without uri_scheme' : 'with uri scheme' do
        should 'correctly parse an IP address without a port' do
          url = uri_scheme + '127.0.0.1'
          assert_equal ['127.0.0.1'], @strategy.send(:parse_url, url)
        end


        should 'correctly parse an IP address a port' do
          url = uri_scheme + '127.0.0.1:11300'
          assert_equal ['127.0.0.1', 11300], @strategy.send(:parse_url, url)
        end


        should 'correctly parse a hostname without a port' do
          url = uri_scheme + 'localhost'
          assert_equal ['localhost'], @strategy.send(:parse_url, url)
        end


        should 'correctly parse a hostname with a port' do
          url = uri_scheme + 'localhost:11300'
          assert_equal ['localhost', 11300], @strategy.send(:parse_url, url)
        end
      end
    end


    should 'raise InvalidURIScheme if uri scheme is not beanstalk' do
      assert_raises(ArgumentError) do
        @strategy.send(:parse_url, 'http://localhost:11300')
      end
    end

  end


  context 'tests against real servers' do

    setup do
      create_test_beanstalks
    end


    context 'enumerators' do

      %w[jobs tubes].each do |enumerator|
        enumerator_singular = enumerator[0, enumerator.length - 1]

        context "##{enumerator_singular}_enumerator" do

          should 'return an enumerator' do
            assert_kind_of Enumerator, @strategy.send(enumerator)
          end


          should "iterate over all #{enumerator} on all beanstalks" do
            expected_count = @beanstalks.length
            iterated_count = 0
            @beanstalks.each_with_index do |beanstalk, index|
              stub = enumerator == 'jobs' ? [index] : {index => index}
              beanstalk.stubs(enumerator).returns(stub)
            end
            @strategy.expects("strategy_#{enumerator_singular}").
              times(expected_count).
              returns(*(expected_count.times.to_a))
            enums = @strategy.send(enumerator).to_a
            enums.each_with_index do |enumerable, index|
              assert_equal index, enumerable
              iterated_count += 1
            end

            assert_equal expected_count, iterated_count
          end

        end

      end


      context '#jobs' do

        should 'get actual jobs when not mocked' do
          @strategy.jobs.each do |job|
            assert @strategy.delete_job(job)
          end
          @beanstalks.each_with_index do |beanstalk, index|
            beanstalk.direct_connection_client.transmit("put 0 0 120 1\r\n#{index}")
          end
          @strategy.jobs.each_with_index do |job, index|
            assert_kind_of BeanCounter::Strategy::GemeraldBeanstalkStrategy::Job, job
            assert_equal index.to_s, job.body
          end
        end

      end


      context '#tubes' do

        should 'get merged tube stats when not mocked' do
          shared_tube = SecureRandom.uuid
          tube_names = @@gemerald_clients.values.map do |client|
            tube_name = SecureRandom.uuid
            client.transmit("watch #{tube_name}")
            client.transmit("watch #{shared_tube}")
            tube_name
          end
          tube_names.concat(['default', shared_tube])
          @strategy.tubes.each do |tube|
            tube_names.delete(tube.name)
          end
          assert tube_names.empty?, 'Expected all tubes to be enumerated'
        end

      end

    end


    context '#collect_new_jobs' do

      should 'raise ArgumentError unless block given' do
        assert_raises(ArgumentError) do
          @strategy.collect_new_jobs
        end
      end


      should 'return empty array if no jobs enqueued by block' do
        new_jobs = @strategy.collect_new_jobs {}
        assert_equal [], new_jobs
      end


      should 'only return jobs enqueued during the execution of the given block' do
        tube_name = message = SecureRandom.uuid
        other_client = client(@@gemerald_addrs.last)
        [client, other_client].each do |gb_client|
          gb_client.transmit("use #{tube_name}")
          gb_client.transmit("watch #{tube_name}")
          gb_client.transmit('ignore default')
          gb_client.transmit("put 0 0 120 #{message.bytesize}\r\n#{message}")
        end
        # Add an extra job to first client to make id lists unequal and help test order
        message = SecureRandom.uuid
        client.transmit("put 0 0 120 #{message.bytesize}\r\n#{message}")

        jobs = []
        new_jobs = @strategy.collect_new_jobs do
          [client, other_client].each do |gb_client|
            5.times do
              message = SecureRandom.uuid
              response = gb_client.transmit("put 0 0 120 #{message.bytesize}\r\n#{message}")
              jobs << insertion_id(response)
            end
          end
        end

        [client, other_client].each do |gb_client|
          message = SecureRandom.uuid
          gb_client.transmit("put 0 0 120 #{message.bytesize}\r\n#{message}")
        end
        assert_equal new_jobs.map{|job| job.id}, jobs
      end

    end


    context '#delete_job' do

      should 'delete the given job and return true' do
        message = SecureRandom.uuid
        response = client.transmit("put 0 0 120 #{message.bytesize}\r\n#{message}")
        job_id = insertion_id(response)
        job = strategy_job(client, job_id)
        assert @strategy.delete_job(job), 'Failed to delete job'
        assert_equal 'deleted', job.state
        assert_equal "NOT_FOUND\r\n", client.transmit("stats-job #{job_id}")
      end


      should 'return true if the job has already been deleted' do
        message = SecureRandom.uuid
        response = client.transmit("put 0 0 120 #{message.bytesize}\r\n#{message}")
        job_id = insertion_id(response)
        job = strategy_job(client, job_id)
        assert @strategy.delete_job(job), 'Failed to delete job'
        assert @strategy.delete_job(job), 'Expected deleting a deleted job to return true'
      end


      should 'return false if the job could not be deleted' do
        tube_name = message = SecureRandom.uuid
        other_client = client.beanstalk.direct_connection_client
        other_client.transmit("use #{tube_name}")
        other_client.transmit("watch #{tube_name}")
        other_client.transmit('ignore defualt')
        response = other_client.transmit("put 0 0 120 #{message.bytesize}\r\n#{message}")
        job_id = insertion_id(response)
        other_client.transmit('reserve')
        job = strategy_job(client, job_id)
        assert_equal 'reserved', job.state
        refute @strategy.delete_job(job), 'Expected deleting job reserved by other client to fail'
        other_client.transmit("delete #{job_id}")
      end

    end


    context '#job_matches?' do

      setup do
        @message = @tube_name = SecureRandom.uuid
        client.transmit("use #{@tube_name}")
        response = client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
        job_id = insertion_id(response)
        @job = strategy_job(client, job_id)
      end


      should 'match string fields using string or regex' do
        {
          :body => @message,
          :state => @job.state,
          :tube => @tube_name,
        }.each_pair do |key, value|
          assert @strategy.job_matches?(@job, key => value)
          assert @strategy.job_matches?(@job, key => %r[#{value[2, 3]}])
          refute @strategy.job_matches?(@job, key => 'foobar')
          refute @strategy.job_matches?(@job, key => /foobar/)
        end
      end


      should 'match integer fields using integer or range' do
        verify_attrs(@job, {
          :age => @job.age,
          :buries => @job.buries,
          :delay => @job.delay,
          :id => @job.id,
          :kicks => @job.kicks,
          :pri => @job.pri,
          :releases => @job.releases,
          :reserves => @job.reserves,
          :'time-left' => @job.time_left,
          :timeouts => @job.timeouts,
          :ttr => @job.ttr,
        })
      end


      should 'match integer fields using integer or range (with more stubs)' do
        job_attrs = {
          'age' => 100,
          'buries' => 101,
          'delay' => 102,
          'kicks' => 103,
          'pri' => 104,
          'releases' => 105,
          'reserves' => 106,
          'time-left' => 107,
          'timeouts' => 108,
          'ttr' => 109,
        }
        @job.stubs(:exists?).returns(true)
        @job.instance_variable_get(:@gemerald_job).stubs(:stats).returns(job_attrs)
        verify_attrs(@job, job_attrs)
      end


      should 'be able to match with a proc' do
        matching_connection_proc = proc do |connection|
          connection.beanstalk.address == '127.0.0.1:11400'
        end
        assert @strategy.job_matches?(@job, :connection => matching_connection_proc)

        failing_connection_proc = proc do |connection|
          connection.beanstalk.address != '127.0.0.1:11400'
        end
        refute @strategy.job_matches?(@job, :connection => failing_connection_proc)
      end


      should 'not try to match on non-matachable attributes' do
        # Should never be called
        @job.expects(:bury).never
        @job.expects(:delete).never
        @job.expects(:deadline_approaching).never

        assert @strategy.job_matches?(@job, {
          :body => @message,
          :bury => 'baz',
          :deadline_approaching => 'bar',
          :delete => 'bar',
          :stats => 'boom',
        })
      end


      should 'not match deleted job' do
        client.transmit("delete #{@job.id}")
        refute @strategy.job_matches?(@job, :body => @message)
      end

    end


    context '#pretty_print_job' do

      setup do
        @message = @tube_name = SecureRandom.uuid
        client.transmit("use #{@tube_name}")
        response = client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
        job_id = insertion_id(response)
        @job = strategy_job(client, job_id)
      end


      should 'return expected text representation of job' do
        stats = {
          'age' => age = 3,
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
        @job.expects(:stats).returns(stats)
        expected = %W[
          "age"=>#{age} "body"=>"#{@message}" "buries"=>#{buries}
          "delay"=>#{delay} "id"=>#{id} "kicks"=>#{kicks} "pri"=>#{pri} "releases"=>#{releases}
          "reserves"=>#{reserves} "state"=>"#{state}" "time-left"=>#{time_left}
          "timeouts"=>#{timeouts} "ttr"=>#{ttr} "tube"=>"#{tube}"
        ].join(', ')
        assert_equal "{#{expected}}", @strategy.pretty_print_job(@job)
      end

    end


    context '#pretty_print_tube' do

      setup do
        @tube_name = SecureRandom.uuid
        client.transmit("watch #{@tube_name}")
        @tube = strategy_tube(@tube_name)

        other_client = client(@@gemerald_addrs.last)
        other_client.transmit("watch #{@tube_name}")
      end


      should 'return expected text representation of tube' do
        stats = {
          'cmd-delete' => cmd_delete = 100,
          'cmd-pause-tube' => cmd_pause_tube = 101,
          'current-jobs-buried' => current_jobs_buried = 102,
          'current-jobs-delayed' => current_jobs_delayed = 103,
          'current-jobs-ready' => current_jobs_ready = 104,
          'current-jobs-reserved' => current_jobs_reserved = 105,
          'current-jobs-urgent' => current_jobs_urgent = 106,
          'current-using' => current_using = 107,
          'current-waiting' => current_waiting = 108,
          'current-watching' => current_watching = 109,
          'name' => name = @tube_name,
          'pause' => pause = 111,
          'pause-time-left' => pause_time_left = 110,
          'total-jobs' => total_jobs = 112,
        }
        GemeraldBeanstalk::Tube.any_instance.expects(:stats).twice.returns(stats)
        expected = %W[
          "cmd-delete"=>#{cmd_delete * 2} "cmd-pause-tube"=>#{cmd_pause_tube * 2}
          "current-jobs-buried"=>#{current_jobs_buried * 2}
          "current-jobs-delayed"=>#{current_jobs_delayed * 2}
          "current-jobs-ready"=>#{current_jobs_ready * 2}
          "current-jobs-reserved"=>#{current_jobs_reserved * 2}
          "current-jobs-urgent"=>#{current_jobs_urgent * 2}
          "current-using"=>#{current_using * 2} "current-waiting"=>#{current_waiting * 2}
          "current-watching"=>#{current_watching * 2} "name"=>"#{name}"
          "pause"=>#{pause * 2} "pause-time-left"=>#{pause_time_left * 2}
          "total-jobs"=>#{total_jobs * 2}
        ].join(', ')
        assert_equal "{#{expected}}", @strategy.pretty_print_tube(@tube)
      end

    end


    context '#tube_matches?' do

      setup do
        @tube_name = SecureRandom.uuid
        client.transmit("watch #{@tube_name}")
        @tube = strategy_tube(@tube_name)
      end


      should 'match name using string or regex' do
        assert @strategy.tube_matches?(@tube, :name => @tube_name)
        assert @strategy.tube_matches?(@tube, :name => %r[#{@tube_name[2, 3]}])
        refute @strategy.tube_matches?(@tube, :name => 'foobar')
        refute @strategy.tube_matches?(@tube, :name => /foobar/)
      end


      should 'match integer fields using integer or range' do
        tube_stats = @tube.to_hash
        verify_attrs(@tube, {
          'cmd-delete' => tube_stats['cmd-delete'],
          'cmd-pause-tube' => tube_stats['cmd-pause-tube'],
          'current-jobs-buried' => tube_stats['current-jobs-buried'],
          'current-jobs-delayed' => tube_stats['current-jobs-delayed'],
          'current-jobs-ready' => tube_stats['current-jobs-ready'],
          'current-jobs-reserved' => tube_stats['current-jobs-reserved'],
          'current-jobs-urgent' => tube_stats['current-jobs-urgent'],
          'current-using' => tube_stats['current-using'],
          'current-waiting' => tube_stats['current-waiting'],
          'current-watching' => tube_stats['current-watching'],
          'pause' => tube_stats['pause'],
          'pause-time-left' => tube_stats['pause-time-left'],
          'total-jobs' => tube_stats['total-jobs'],
        })
      end


      should 'match integer fields using integer or range (with more stubs)' do
        tube_attrs = {
          'cmd-delete' => 100,
          'cmd-pause-tube' => 101,
          'current-jobs-buried' => 102,
          'current-jobs-delayed' => 103,
          'current-jobs-ready' => 104,
          'current-jobs-reserved' => 105,
          'current-jobs-urgent' => 106,
          'current-using' => 107,
          'current-waiting' => 108,
          'current-watching' => 109,
          'pause-time-left' => 110,
          'pause' => 111,
          'total-jobs' => 112,
        }
        @tube.stubs(:to_hash).returns(tube_attrs)
        verify_attrs(@tube, tube_attrs)
      end


      should 'be able to match with a proc' do
        matching_name_proc = proc do |name|
          name == @tube_name
        end
        assert @strategy.tube_matches?(@tube, :name => matching_name_proc)

        failing_name_proc = proc do |name|
          name != @tube_name
        end
        refute @strategy.tube_matches?(@tube, :name => failing_name_proc)
      end


      should 'not try to match on non-matachable attributes' do
        %w[delete put reserve].each do |method|
          @tube.expects(method).never
        end

        assert @strategy.tube_matches?(@tube, {
          :delete => true,
          :name => @tube_name,
          :put => true,
          :reserve => true,
        })
      end


      should 'not match tube that no longer exists' do
        client.transmit("ignore #{@tube_name}")
        refute @tube.exists?
        refute @strategy.tube_matches?(@tube)
      end

    end

  end


  def client(addr = nil)
    return gemerald_client(addr)
  end


  def create_test_beanstalks
    self.class.create_test_gemerald_beanstalks
    @strategy = @@gemerald_strategy
    @beanstalks = @@gemerald_beanstalks
  end


  def insertion_id(response)
    return response.scan(/INSERTED (\d+)\r\n/).flatten.first.to_i
  end


  def strategy_job(gb_client, job_id)
    gb_job = gb_client.beanstalk.jobs.reverse.detect{|job| job.id == job_id}
    return @strategy.send(:strategy_job, gb_job)
  end


  def strategy_tube(tube_name)
    return @strategy.send(:strategy_tube, tube_name)
  end


  def verify_attrs(strategy_object, attrs)
    method = strategy_object.is_a?(BeanCounter::Strategy::GemeraldBeanstalkStrategy::Job) ? :job_matches? : :tube_matches?
    attrs.each_pair do |key, value|
      obj_hash = strategy_object.to_hash
      sanitized_key = key.to_s
      assert(
        @strategy.send(method, strategy_object, key => value),
        "Expected #{key} (#{obj_hash[sanitized_key]}) to match #{value}"
      )
      assert(
        @strategy.send(method, strategy_object, key => (value - 5)..(value + 1)),
        "Expected #{key} (#{obj_hash[sanitized_key]}) to match #{value} +/-5"
      )
      refute(
        @strategy.send(method, strategy_object, key => value - 1),
        "Expected #{key} (#{obj_hash[sanitized_key]}) to not match #{value}"
      )
      refute(
        @strategy.send(method, strategy_object, key => (value + 100)..(value + 200)),
        "Expected #{key} (#{obj_hash[sanitized_key]}) to not match #{value + 100}..#{value + 200}"
      )
    end
  end

end
