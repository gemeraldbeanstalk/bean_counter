require 'spec_helper'
require 'securerandom'

# Fuller testing of matchers handled by strategy and matcher tests. Just make
# sure matchers work as expected at high level
describe BeanCounter::Spec do

  before(:each) do
    BeanCounter.reset!
    @tube_name = SecureRandom.uuid
    client.transmit("use #{@tube_name}")
    @message = SecureRandom.uuid
  end


  describe 'enqueued job matcher' do

    describe 'positive match' do

      it 'should match any matching job when not given a count' do
        should_not have_enqueued(:body => @message)
        proc do
          2.times do
            client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
          end
        end.should have_enqueued(:body => @message)
        should have_enqueued(:body => @message)
      end


      it 'should match count exactly when given integer count' do
        should_not have_enqueued(:body => @message)
        proc do
          client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
        end.should have_enqueued(:body => @message, :count => 1)
        should have_enqueued(:body => @message, :count => 1)
      end


      it 'should match count to range when given range' do
        should_not have_enqueued(:body => @message)
        proc do
          2.times do
            client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
          end
        end.should have_enqueued(:body => @message, :count => 1..3)
        should have_enqueued(:body => @message, :count => 1..3)
      end


      it 'should not match when no matching jobs are found' do
        message = SecureRandom.uuid
        ::RSpec::Expectations.expects(:fail_with)
        proc do
          client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
        end.should have_enqueued(:body => message)
        should have_enqueued(:body => @message)
        should_not have_enqueued(:body => message)
      end


      it 'should not match with exact count when given integer count' do
        should_not have_enqueued(:body => @message)
        ::RSpec::Expectations.expects(:fail_with)
        proc do
          client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
        end.should have_enqueued(:body => @message, :count => 2)
        should have_enqueued(:body => @message, :count => 1)
      end


      it 'should not match when no matching jobs are enqueued during block' do
        client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
        ::RSpec::Expectations.expects(:fail_with)
        (proc {}).should have_enqueued(:body => @message)
        should have_enqueued(:body => @message)
      end

    end


    describe 'negative match' do

      it 'should match when no matching jobs are found' do
        message = SecureRandom.uuid
        proc do
          client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
        end.should_not have_enqueued(:body => message)
        should have_enqueued(:body => @message)
        should_not have_enqueued(:body => message)
      end


      it 'should match with exact count when given integer count' do
        should_not have_enqueued(:body => @message)
        proc do
          client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
        end.should_not have_enqueued(:body => @message, :count => 2)
        should have_enqueued(:body => @message, :count => 1)
      end


      it 'should match when no matching jobs are enqueued during block' do
        client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
        (proc {}).should_not have_enqueued(:body => @message)
        should have_enqueued(:body => @message)
      end


      it 'should not match when not given a count and job found' do
        should_not have_enqueued(:body => @message)
        ::RSpec::Expectations.expects(:fail_with)
        proc do
          2.times do
            client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
          end
        end.should_not have_enqueued(:body => @message)
        should have_enqueued(:body => @message)
      end


      it 'should not match when found count matches expected count' do
        should_not have_enqueued(:body => @message)
        ::RSpec::Expectations.expects(:fail_with)
        proc do
          client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
        end.should_not have_enqueued(:body => @message, :count => 1)
        should have_enqueued(:body => @message, :count => 1)
      end


      it 'should not match when found count falls in expected range' do
        should_not have_enqueued(:body => @message)
        ::RSpec::Expectations.expects(:fail_with)
        proc do
          2.times do
            client.transmit("put 0 0 120 #{@message.bytesize}\r\n#{@message}")
          end
        end.should_not have_enqueued(:body => @message, :count => 1..3)
        should have_enqueued(:body => @message, :count => 1..3)
      end
    end

  end


  describe 'tube matcher' do

    describe 'positive match' do

      it 'should match when matching tube found' do
        client.transmit("put 0 0 120 2\r\nxx")
        client.transmit("put 0 120 120 2\r\nxx")
        client.transmit("pause-tube #{@tube_name} 0")

        should have_tube({
          'name' => @tube_name,
          'cmd-pause' => 1..3,
          'current-jobs-ready' => 1,
          'current-jobs-delayed' => 1,
          'current-using' => 1,
        })
      end


      it 'should not match when no matching tubes are found' do
        should_not have_tube(:name => SecureRandom.uuid)

        default_stats = client.transmit('stats-tube default')[:body]
        urgent = default_stats['current-jobs-urgent']
        should_not have_tube({
          'name' => 'default',
          'current-jobs-urgent' => (urgent + 5)..(urgent + 10),
        })
        watching = default_stats['current-watching']
        ::RSpec::Expectations.expects(:fail_with)
        should have_tube({
          'name' => 'default',
          'current-watching' => watching + 10,
        })
      end

    end


    describe 'negative match' do

      it 'should match when no matching tubes are found' do
        should_not have_tube(:name => SecureRandom.uuid)

        default_stats = client.transmit('stats-tube default')[:body]
        urgent = default_stats['current-jobs-urgent']
        should_not have_tube({
          'name' => 'default',
          'current-jobs-urgent' => (urgent + 5)..(urgent + 10),
        })
        watching = default_stats['current-watching']
        should_not have_tube({
          'name' => 'default',
          'current-watching' => watching + 10,
        })
      end


      it 'should not match when matching tube found' do
        client.transmit("put 0 0 120 2\r\nxx")
        client.transmit("put 0 120 120 2\r\nxx")
        client.transmit("pause-tube #{@tube_name} 0")

        ::RSpec::Expectations.expects(:fail_with)
        should_not have_tube({
          'name' => @tube_name,
          'cmd-pause' => 1..3,
          'current-jobs-ready' => 1,
          'current-jobs-delayed' => 1,
          'current-using' => 1,
        })
      end

    end

  end

end
