require 'test_helper'

class TubeExpectationTest < BeanCounter::TestCase

  TubeExpectation = BeanCounter::TubeExpectation

  context 'failure message' do

    setup do
      @expectation = TubeExpectation.new({})
    end


    should 'return expected message if no tube found' do
      @expectation.strategy.tubes.expects(:detect).returns(nil)
      @expectation.expected.expects(:to_s).returns('expected')
      refute @expectation.matches?
      expected = 'expected tube matching expected, found none.'
      assert_equal expected, @expectation.failure_message
    end


    should 'return empty string if tube found' do
      @expectation.strategy.tubes.expects(:detect).returns(:tube)
      assert @expectation.matches?
      assert_equal '', @expectation.failure_message
    end

  end


  context '#new' do

    should 'set expected correctly' do
      expected = {:name => 'some_tube'}
      expectation = TubeExpectation.new(expected)
      assert_equal expected, expectation.expected
    end

  end


  context '#matches?' do

    setup do
      @expectation = TubeExpectation.new({})
    end


    should 'return true and set found if strategy.tubes includes match' do
      @expectation.strategy.expects(:tubes).returns([:wrong_tube, :right_tube, :wrong_tube])
      @expectation.strategy.expects(:tube_matches?).twice.returns(false, true)
      assert @expectation.matches?
      assert_equal :right_tube, @expectation.found
    end


    should 'return false and set found if strategy does not include match' do
      @expectation.strategy.expects(:tubes).returns([:wrong_tube])
      @expectation.strategy.expects(:tube_matches?).returns(false)
      refute @expectation.matches?({})
      assert_nil @expectation.found
    end

  end


  context '#negative_failure_message' do

    setup do
      @expectation = TubeExpectation.new({})
    end


    should 'return empty string if nothing found' do
      @expectation.strategy.expects(:tubes).returns([])
      refute @expectation.matches?
      assert_equal '', @expectation.negative_failure_message
    end


    should 'return expected message if a tube found' do
      @expectation.strategy.tubes.expects(:detect).returns(:tube)
      @expectation.strategy.expects(:pretty_print_tube).returns('tube')
      @expectation.expected.expects(:to_s).returns('expected')
      assert @expectation.matches?
      expected = 'expected no tubes matching expected, found tube'
      assert_equal expected, @expectation.negative_failure_message
    end

  end

end
