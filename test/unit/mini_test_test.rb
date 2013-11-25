require 'test_helper'
require 'securerandom'

class MiniTestTest < BeanCounter::TestCase

  setup do
    reset!
    @tube_name = SecureRandom.uuid
    client.transmit("use #{@tube_name}")
    @message = SecureRandom.uuid
  end


  # Fuller testing of strategies handled by strategy tests
  # Just make sure assertions work as expected at high level
  context 'simple assertion tests' do

    should 'match any matching job when not given a count' do
      refute_enqueued(:body => @message)
      assert_enqueues(:body => @message) do
        2.times do
          client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
        end
      end
      assert_enqueued(:body => @message)
    end


    should 'match count exactly when given integer count' do
      refute_enqueued(:body => @message)
      assert_enqueues(:body => @message, :count => 1) do
        client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
      end
      assert_enqueued(:body => @message, :count => 1)
    end


    should 'match count to range when given range' do
      refute_enqueued(:body => @message)
      assert_enqueues(:body => @message, :count => 1..3) do
        2.times do
          client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
        end
      end
      assert_enqueued(:body => @message, :count => 1..3)
    end


    context 'assert expectations' do

      setup do
        # Setting expectation for call count behaves strangely probably because
        # of expectation on assert. So count assertions manually
        @assert_calls = 0
        self.expects(:assert).at_least_once.with do |truth, message|
          @assert_calls += 1
          !truth
        end
      end


      should 'fail assertion when no matching jobs enqueued' do
        assert_enqueues(:body => /.*/) { }
        assert_enqueued(:body => /.*/)

        reset_expectations
        assert_equal 2, @assert_calls
      end


      should 'fail assertion when no matching jobs enqueued during block' do
        client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
        assert_enqueues(:body => @message) {}
        refute_enqueued(:body => %r[(?!#{@message})])

        reset_expectations
        # Refute calls assert, so assert_calls is incremented
        assert_equal 2, @assert_calls
      end


      should 'fail assertion when too few matching jobs enqueued' do
        assert_enqueues(:body => @message, :count => 2) do
          client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
        end
        assert_enqueued(:body => @message, :count => 2)

        reset_expectations
        assert_equal 2, @assert_calls
      end


      should 'fail assertion when too many matching jobs enqueued' do
        assert_enqueues(:body => @message, :count => 1) do
          2.times do
            client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
          end
        end
        assert_enqueued(:body => @message, :count => 1)

        reset_expectations
        assert_equal 2, @assert_calls
      end


      should 'fail assertion when number of matching jobs outside given range' do
        assert_enqueues(:body => @message, :count => 1..2) do
          3.times do
            client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
          end
        end
        assert_enqueued(:body => @message, :count => 1..2)

        reset_expectations
        assert_equal 2, @assert_calls
      end

    end

  end


  context 'refutations' do

    should 'pass refutation when no matching jobs are found' do
      message = SecureRandom.uuid
      refute_enqueues(:body => message) do
        client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
      end
      assert_enqueued(:body => @message)
      refute_enqueued(:body => message)
    end


    should 'pass refutation when if no matching jobs are enqueued during block' do
      client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
      refute_enqueues(:body => @message) {}
      assert_enqueued(:body => @message)
    end


    context 'refute expectations' do

      should 'fail refutation when any matching jobs are enqueued' do
        # Setting expectation for call count behaves strangely probably because
        # of expectation on refute. So count refutaions manually
        @refute_calls = 0
        self.expects(:assert).at_least_once.with do |truth, message|
          @refute_calls += 1
          !truth
        end
        uuid = SecureRandom.uuid
        client.transmit("use #{uuid}")
        refute_enqueues(:body => /.*/) do
          client.transmit("put 0 0 120 #{uuid.bytesize}\r\n#{uuid}")
        end
        refute_enqueued(:body => /.*/)

        reset_expectations
        assert_equal 2, @refute_calls
      end

    end

  end


  context 'reset!' do

    should 'remove all jobs from all tubes when not given a tube name' do
      jobs = []
      jobs << client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")[:id]
      client.transmit("watch #{@tube_name}")
      client.transmit('ignore default')
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

      reset!
      jobs.each do |job_id|
        assert_raises(Beaneater::NotFoundError) do
          client.transmit("stats-job #{job_id}")
        end
      end
    end


    should 'only remove jobs from the specified tube when given a tube name' do
      jobs = []
      jobs << client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")[:id]
      client.transmit("watch #{@tube_name}")
      client.transmit('ignore default')
      timeout(1) do
        job_id = client.transmit('reserve')[:id]
        client.transmit("bury #{job_id} 0")
      end
      jobs << client.transmit("put 0 1024 120 #{@message.bytesize}\r\n#{@message}")[:id]

      client.transmit("use #{SecureRandom.uuid}")
      other_job_id = client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")[:id].to_i

      reset!(@tube_name)
      jobs.each do |job_id|
        assert_raises(Beaneater::NotFoundError) do
          client.transmit("stats-job #{job_id}")
        end
      end
      assert_equal other_job_id, client.transmit("stats-job #{other_job_id}")[:body]['id']
    end

  end


  def reset_expectations
    # Must manually call mocha_teardown inside test body or expectation
    # when setting expectation on assert or refute, otherwise expectation
    # survives to the next test
    mocha_teardown
  end

end