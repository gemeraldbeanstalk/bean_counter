class BeanCounter::Strategy

  MATCHABLE_JOB_ATTRIBUTES = begin
      attrs = [
      :age, :body, :buries, :connection, :delay, :id, :kicks, :pri, :releases,
      :reserves, :state, :'time-left', :timeouts, :ttr, :tube,
    ]
    attrs.concat(attrs.map(&:to_s))
  end

  MATCHABLE_TUBE_ATTRIBUTES = begin
    attrs = [
      :'cmd-delete', :'cmd-pause-tube', :'current-jobs-buried',
      :'current-jobs-delayed', :'current-jobs-ready', :'current-jobs-reserved',
      :'current-jobs-urgent', :'current-using', :'current-waiting',
      :'current-watching', :name, :pause, :'pause-time-left', :'total-jobs',
    ]
    attrs.concat(attrs.map(&:to_s))
  end

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
  def collect_new_jobs
    raise NotImplementedError
  end


  # Provide a means for deleting a job specific to the job interface used by
  # the strategy
  def delete_job
    raise NotImplementedError
  end


  # Different strategies may provide different interfaces for what jobs look like
  # so they should provide a custom method to determine if a job matches
  # a supplied hash of attributes
  def job_matches?
    raise NotImplementedError
  end


  # Provide means for enumerating all jobs
  def jobs
    raise NotImplementedError
  end


  # Provide a means for pretty printing of strategy job
  def pretty_print_job
    raise NotImplementedError
  end


  # Provide a means for pretty printing of strategy tube
  def pretty_print_tube
    raise NotImplementedError
  end


  # Different strategies may provide different interfaces for what tubes look like
  # so they should provide a custom method to determine if a tube matches
  # a supplied hash of attributes
  def tube_matches?
    raise NotImplementedError
  end


  # Provide means for enumerating all tubes
  def tubes
    raise NotImplementedError
  end

end
