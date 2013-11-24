class BeanCounter::Strategy

  include Enumerable

  MATCHABLE_ATTRIBUTES = [
    :age, :body, :buries, :delay, :id, :kicks, :pri, :releases,
    :reserves, :state, :"time-left", :timeouts, :ttr, :tube,
  ]

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


  # Provide a means for collecting jobs enqueued during the execution of the
  # provided block
  def collect_new
    raise NotImplementedError
  end


  # Provide means for enumerating all jobs
  def each
    raise NotImplementedError
  end


  # Different strategies may provide different interfaces for what jobs look like
  # so they should provide a custom method to determine if a job matches
  # a supplied hash of attributes
  def job_matches?
    raise NotImplementedError
  end


  def select_with_limit(limit = 1)
    raise ArgumentError, 'Block required' unless block_given?
    return [] if limit <= 0

    selected = []
    each do |element|
      next unless yield(element)
      selected << element
      return selected if selected.length >= limit
    end
  end


end
