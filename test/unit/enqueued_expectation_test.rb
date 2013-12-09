require 'test_helper'

class EnqueuedExpectationTest < BeanCounter::TestCase

  EnqueuedExpectation = BeanCounter::EnqueuedExpectation

  context '#collection_matcher' do

    should 'traverse collection with detect and return true if no count given' do
      expectation = EnqueuedExpectation.new({})
      collection = [:job]
      collection.expects(:detect).once.returns(:job)
      expectation.strategy.expects(:jobs).returns(collection)
      assert expectation.matches?
      assert_equal collection, expectation.found
    end


    should 'traverse collection with select and return true if count matches' do
      expectation = EnqueuedExpectation.new({:count => 1})
      collection = [:job]
      collection.expects(:select).once.returns(collection)
      expectation.strategy.expects(:jobs).returns(collection)
      assert expectation.matches?
      assert_equal collection, expectation.found
    end


    should 'return false and set found if strategy does not include match' do
      expectation = EnqueuedExpectation.new({})
      expectation.strategy.expects(:jobs).returns([:wrong_job])
      expectation.strategy.expects(:job_matches?).returns(false)
      refute expectation.matches?
      assert_nil expectation.found
    end


    should 'return false and set found if strategy does not include expected number of matches' do
      collection = [:job, :job, :job]
      [{:count => 0}, {:count => 1}, {:count => 2}, {:count => 1..2}].each do |expected|
        expectation = EnqueuedExpectation.new(expected)
        expectation.strategy.expects(:jobs).returns(collection)
        expectation.strategy.expects(:job_matches?).times(3).returns(true)
        refute expectation.matches?
        assert_equal collection, expectation.found
      end
    end

  end


  context '#expected_count?' do

    should 'return true if a certain number of matches expected' do
      expectation = EnqueuedExpectation.new(:count => 5)
      assert expectation.expected_count?
    end


    should 'return false if any number of matches expected' do
      expectation = EnqueuedExpectation.new({})
      refute expectation.expected_count?
    end

  end


  context '#failure message' do

    should 'return expected message if nothing found and no count' do
      expected = {}
      expectation = EnqueuedExpectation.new(expected)
      expected.expects(:to_s).returns('expected')
      expected = 'expected any number of jobs matching expected, found none'
      assert_equal expected, expectation.failure_message
    end


    should 'return expected message if nothing found and count given' do
      expected = {:count => 3}
      expectation = EnqueuedExpectation.new(expected)
      expected.expects(:to_s).returns('expected')
      expected = 'expected 3 jobs matching expected, found none'
      assert_equal expected, expectation.failure_message
    end


    should 'return expected message if number found does not match count given' do
      expected = {:count => 3}
      expectation = EnqueuedExpectation.new(expected)
      expectation.strategy.jobs.expects(:select).returns([:job, :job])
      expectation.matches?
      expectation.strategy.expects(:pretty_print_job).twice.returns('job')
      expected.expects(:to_s).returns('expected')
      expected = "expected 3 jobs matching expected, found 2: job\njob"
      assert_equal expected, expectation.failure_message
    end

  end


  context '#new' do

    should 'set expected correctly' do
      expected = {}
      expectation = EnqueuedExpectation.new(expected)
      assert_equal expectation.expected, expected
    end


    should 'pull out count and set expected_count correctly' do
      expected = {:count => 1}
      expectation = EnqueuedExpectation.new(expected)
      assert_equal({}, expectation.expected)
      assert_equal 1, expectation.expected_count

      expected = {'count' => 2}
      expectation = EnqueuedExpectation.new(expected)
      assert_equal({}, expectation.expected)
      assert_equal 2, expectation.expected_count

      expected = {:count => 3, 'count' => 4}
      expectation = EnqueuedExpectation.new(expected)
      assert_equal({}, expectation.expected)
      assert_equal 3, expectation.expected_count
    end

  end


  context '#matches?' do

    setup do
      @expectation = EnqueuedExpectation.new({})
    end


    should 'call #proc_matcher when given Proc' do
      lamb = lambda {}
      prok = proc {}
      proc_new = Proc.new {}
      @expectation.expects(:proc_matcher).times(3)
      @expectation.matches?(lamb)
      @expectation.matches?(prok)
      @expectation.matches?(proc_new)
    end


    should 'call #collection_macther with strategy.jobs when not given proc' do
      @expectation.expects(:collection_matcher)
      BeanCounter.strategy.expects(:jobs).returns([])
      @expectation.matches?
    end

  end


  context '#negative_failure_message' do

    should 'return empty string if nothing found' do
      expectation = EnqueuedExpectation.new({})
      expectation.strategy.expects(:jobs).returns([])
      refute expectation.matches?
      assert_equal '', expectation.negative_failure_message
    end


    should 'return expected message if matching job found and no count given' do
      expectation = EnqueuedExpectation.new({})
      expectation.strategy.jobs.expects(:detect).returns(:job)
      expectation.strategy.expects(:pretty_print_job).returns('job')
      expectation.expected.expects(:to_s).returns('expected')
      assert expectation.matches?
      expected = 'did not expect any jobs matching expected, found 1: job'
      assert_equal expected, expectation.negative_failure_message
    end


    should 'return expected message if matching job found and count of 1 given' do
      expectation = EnqueuedExpectation.new({:count => 1})
      expectation.strategy.jobs.expects(:select).returns([:job])
      expectation.strategy.expects(:pretty_print_job).returns('job')
      expectation.expected.expects(:to_s).returns('expected')
      assert expectation.matches?
      expected = 'did not expect 1 job matching expected, found 1: job'
      assert_equal expected, expectation.negative_failure_message
    end


    should 'return expected message if matching jobs found and count not equal 1' do
      expectation = EnqueuedExpectation.new({:count => 2})
      expectation.strategy.jobs.expects(:select).returns([:job, :job])
      expectation.strategy.expects(:pretty_print_job).twice.returns('job')
      expectation.expected.expects(:to_s).returns('expected')
      assert expectation.matches?
      expected = "did not expect 2 jobs matching expected, found 2: job\njob"
      assert_equal expected, expectation.negative_failure_message
    end

  end

  context '#proc_matcher' do

    setup do
      @prok = proc {}
      @expectation = EnqueuedExpectation.new({})
    end

    should 'pass provided block to strategy#collect_new_jobs' do
      @expectation.strategy.expects(:collect_new_jobs).returns([])
      refute @expectation.matches?(@prok)
    end


    should 'pass collected jobs to #collection_matcher' do
      @expectation.strategy.expects(:collect_new_jobs).returns([:job])
      @expectation.strategy.expects(:job_matches?).returns(true)
      assert @expectation.matches?(@prok)
    end

  end

end
