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


      should 'return class if strategy is a BeanCounterStrategy' do
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

      should 'define an interface but return NotImplementedError' do
        strategy = BeanCounter::Strategy.new
        BeanCounter::Strategy.public_instance_methods(false).each do |method|
          assert_raises(NotImplementedError) do
            strategy.public_send(method)
          end
        end
      end

    end

  end

end
