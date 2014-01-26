require 'test_helper'

class GemeraldBeanstalkStrategyJobTest < BeanCounter::TestCase

  Job = BeanCounter::Strategy::GemeraldBeanstalkStrategy::Job

  context 'attr methods' do

    should 'respond to stats attr methods and retrieve from #to_hash Hash' do
      Job::STATS_METHODS.each do |attr|
        job = Job.new(stub(:stats => {attr => attr}), nil)
        assert_equal attr, job.send(attr.gsub(/-/, '_'))
      end
    end


    should 'respond to #connection' do
      assert_equal :connection, Job.new(nil, :connection).connection
    end


    should 'retrieve body and stats from gemerald_job' do
      job = Job.new(stub(:stats => :stats, :body => :body), nil)
      assert_equal :body, job.body
      assert_equal :stats, job.stats
    end

  end


  context '#delete' do

    should 'return true if job deleted successfully' do
      job = Job.new(stub(:stats => {'id' => 1}), stub(:transmit => "DELETED\r\n"))
      assert job.delete
    end


    should 'return true if job does not exist' do
      job = Job.new(stub(:stats => {'id' => 1}), stub(:transmit => "NOT_FOUND\r\n"))
      assert job.delete
    end


    should 'return false if job could not be deleted' do
      mock_connection = mock
      mock_connection.expects(:transmit).twice.returns("NOT_FOUND\r\n", "FOUND\r\n")
      job = Job.new(stub(:stats => {'id' => 1, :state => 'ready'}), mock_connection)
      refute job.delete
    end

  end


  context '#exists?' do

    should 'return false if the job state is deleted' do
      job = Job.new(stub(:stats => {'id' => 1, 'state' => 'deleted'}), nil)
      refute job.exists?
    end


    should 'return true if job could be found on server' do
      job = Job.new(stub(:stats => {'id' => 1, 'state' => 'ready'}), stub(:transmit => "FOUND\r\n"))
      assert job.exists?
    end


    should 'return false if job could not be found on server' do
      job = Job.new(stub(:stats => {'id' => 1, 'state' => 'ready'}), stub(:transmit => "NOT_FOUND\r\n"))
      refute job.exists?
    end

  end


  context '#to_hash' do

    should 'return job stats less file with body and connection in alpha order' do
      job = Job.new(stub(:stats => {'file' => :file, 'id' => 1}, :body => :body), :connection)
      assert_equal({'body' => :body, 'connection' => :connection, 'id' => 1}, job.to_hash)
    end

  end

end
