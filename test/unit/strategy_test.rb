require 'test_helper'

class StrategyTest < BeanCounter::TestCase

  context 'Strategy' do

    context 'inherited' do

      should 'maintain a dict of defined strategies' do
        initial_strategies = BeanCounter::Strategy.strategies.keys
        BeanCounter::DummyStrategy = Class.new(BeanCounter::Strategy)
        new_strategy = BeanCounter::Strategy.strategies.keys - initial_strategies
        assert_equal 1, new_strategy.length
        assert_equal BeanCounter::DummyStrategy, BeanCounter::Strategy.strategies[new_strategy.first]
      end

    end


    context 'known_strategy?' do

      should 'return true for items that subclasses of BeanCounter::Strategy' do
        assert BeanCounter::Strategy.known_strategy?(BeanCounter::KnownStrategy)
      end


      should 'try to lookup sym version of identifier if respond to to_sym' do
        assert BeanCounter::Strategy.known_strategy?(:'BeanCounter::KnownStrategy')
        refute BeanCounter::Strategy.known_strategy?('BeanCounter::UnknownStrategy')
      end

    end


    context 'materialize_strategy' do

      should 'raise ArgumentError if unknown strategy' do
        original_strategy = BeanCounter.strategy
        [
          'BeanCounter::UnknownStrategy',
          :'BeanCounter::UnknownStrategy',
          String
        ].each do |bad_strategy|
          assert_raises(ArgumentError) do
            BeanCounter.strategy = bad_strategy
          end
          assert_equal original_strategy, BeanCounter.strategy
        end
      end


      should 'return class form of strategy when given valid strategy' do
        [
          'BeanCounter::KnownStrategy',
          :'BeanCounter::KnownStrategy',
          BeanCounter::KnownStrategy
        ].each do |good_strategy|
          assert_equal(
            BeanCounter::KnownStrategy,
            BeanCounter::Strategy.materialize_strategy(good_strategy)
          )
        end
      end

    end


    context 'strategies' do

      should 'return an immutable dict of strategies' do
        strategies = BeanCounter::Strategy.strategies
        strategies[:Foo] = :Foo
        refute_equal BeanCounter::Strategy.strategies, strategies
      end

    end


    context 'interface methods' do

      setup do
        @strategy = BeanCounter::Strategy.new
      end

      should 'be an Enumberable but each should return NotImplementedError' do
        assert_kind_of Enumerable, @strategy
        assert_raises(NotImplementedError) do
          @strategy.each
        end
      end


      should 'return NotImplementedError for collect_new' do
        assert_raises(NotImplementedError) do
          @strategy.collect_new
        end
      end


      should 'return NotImplementedError for delete_job' do
        assert_raises(NotImplementedError) do
          @strategy.delete_job
        end
      end


      should 'return NotImplementedError for job_matches?' do
        assert_raises(NotImplementedError) do
          @strategy.job_matches?
        end
      end

    end


    context 'select_with_limit' do

      setup do
        @strategy = BeanCounter::Strategy.new
        @strategy.instance_eval do
          extend Forwardable
          def_delegators :collection, :each

          @collection = (1..100).to_a

          def self.collection
            return @collection
          end
        end
      end


      should 'raise ArgumentError if no block given' do
        assert_raises(ArgumentError) do
          @strategy.select_with_limit
        end
      end


      should 'return empty array if limit less than or equal to zero' do
        [0, -5].each do |limit|
          selected = @strategy.select_with_limit(limit) do |element|
            raise 'Block should not have been called with limit <= 0'
          end
          assert_equal [], selected
        end
      end


      should 'select matching elements up to the limit' do
        first_five = @strategy.select_with_limit(5) do |element|
          if element <= 10
            element.even? && element <= 10
          else
            raise 'Unnecessary element traversal. Should have exited loop already'
          end
        end
        assert_equal [2, 4, 6, 8, 10], first_five
      end


      should 'traverse whole collection and return matching elements if limit not reached' do
        selected = @strategy.select_with_limit(@strategy.collection.length + 1) { true }
        assert_equal((1..100).to_a, selected)
      end

    end

  end

end
