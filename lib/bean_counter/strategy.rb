class BeanCounter::Strategy

  @@strategies = {}

  def self.inherited(subclass)
    identifier = subclass.name || subclass.to_s[8, subclass.to_s.length - 9]
    @@strategies[identifier.to_sym] = subclass
  end


  def self.known_strategy?(strategy_identifier)
    return true if strategy_identifier.is_a?(Class) &&
      strategy_identifier <= BeanCounter::Strategy
    return true if strategy_identifier.respond_to?(:to_sym) &&
      strategies.key?(strategy_identifier.to_sym)
    return false
  end


  def self.materialize_strategy(strategy_identifier)
    unless BeanCounter::Strategy.known_strategy?(strategy_identifier)
      raise(
        ArgumentError,
        "Could not find #{strategy_identifier} among known strategies: #{strategies.keys.to_s}"
      )
    end
    return strategy_identifier.is_a?(Class) ? strategy_identifier : strategies[strategy_identifier.to_sym]
  end


  def self.strategies
    return @@strategies.dup
  end


  def delete_matched
    raise NotImplementedError
  end


  def enqueued?
    raise NotImplementedError
  end


  def enqueues?
    raise NotImplementedError
  end


  def reset!
    raise NotImplementedError
  end

end
