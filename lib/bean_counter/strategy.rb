class BeanCounter::Strategy

  # Available job attributes. These attributes can be used by strategies
  # to validate what attributes are used for matching jobs.
  MATCHABLE_JOB_ATTRIBUTES = begin
      attrs = [
      :age, :body, :buries, :connection, :delay, :id, :kicks, :pri, :releases,
      :reserves, :state, :'time-left', :timeouts, :ttr, :tube,
    ]
    attrs.concat(attrs.map(&:to_s))
  end

  # Available tube attributes. These attributes can be used by strategies
  # to validate what attributes are used for matching tubes.
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


  # Maintain an index of classes known to subclass Strategy.
  def self.inherited(subclass)
    identifier = subclass.name || subclass.to_s[8, subclass.to_s.length - 9]
    @@strategies[identifier.to_sym] = subclass
  end


  # :call-seq:
  #   known_strategy?(strategy_identifier) => Boolean
  #
  # Determines if the provided +strategy_identifer+ corresponds to a known
  # subclass of strategy. The provided +strategy_identifer+ can be a class
  # or any object that responds to :to_sym. Classes are compared directly.
  # For non-class objects that respond to :to_sym, the symbolized form
  # of +strategy_identifer+ is used as a key to attempt to retrieve a strategy
  # from the strategies Hash.
  #
  # Returns true if +strategy_identifier+ isa known strategy or maps to a known
  # strategy. Otherwise, false is returned.
  #
  #   BeanCounter::Strategy.known_strategy?(Object)
  #     #=> false
  #
  #   BeanCounter::Strategy.known_strategy?(BeanCounter::Strategy)
  #     #=> true
  def self.known_strategy?(strategy_identifier)
    return true if strategy_identifier.is_a?(Class) &&
      strategy_identifier <= BeanCounter::Strategy
    return true if strategy_identifier.respond_to?(:to_sym) &&
      strategies.key?(strategy_identifier.to_sym)
    return false
  end


  # :call-seq:
  #   materialize_strategy(strategy_identifier) => subclass of Strategy
  #
  # Materialize the provided +strategy_identifier+ into a subclass of Strategy.
  # If +strategy_identifer+ is already a subclass of Strategy,
  # +strategy_identifier+ is returned. Otherwise, +strategy_identifer+ is
  # converted into a Symbol and is used as a key to retrieve a strategy from
  # the known subclasses of Strategy. If +strategy_identifier does not map to
  # a known subclass of Strategy, an ArgumentError is raised.
  #
  #   BeanCounter::Strategy.materialize_strategy(:'BeanCounter::Strategy::StalkClimberStrategy')
  #     #=> BeanCounter::Strategy::StalkClimberStrategy
  def self.materialize_strategy(strategy_identifier)
    unless BeanCounter::Strategy.known_strategy?(strategy_identifier)
      raise(
        ArgumentError,
        "Could not find #{strategy_identifier} among known strategies: #{strategies.keys.to_s}"
      )
    end
    return strategy_identifier.is_a?(Class) ? strategy_identifier : strategies[strategy_identifier.to_sym]
  end


  # :call-seq:
  #   strategies() => Hash
  #
  # Returns a list of known classes that inherit from BeanCounter::Strategy.
  # Typically this list represents the strategies available for interacting
  # with beanstalkd.
  def self.strategies
    return @@strategies.dup
  end


  # :call-seq:
  #   collect_new_jobs { block } => Array[Strategy Job]
  #
  # Provide a means of collecting jobs enqueued during the execution of the
  # provided +block+. Returns an Array of Jobs as implemented by the Strategy.
  #
  # Used internally to reduce the set of jobs that must be examined to evaluate
  # the truth of an assertion to only those enqueued during the evaluation of
  # the given +block+.
  #
  #   new_jobs = strategy.collect_new_jobs do
  #     ...
  #   end
  #     #=> [job_enqueued_during_block, job_enqueued_during_block]
  def collect_new_jobs
    raise NotImplementedError
  end


  # :call-seq:
  #   delete_job(job) => Boolean
  #
  # Provide a means for deleting a job specific to the job interface used by
  # the strategy. Should return true if the job was deleted successfully or
  # no longer exists and false if the job could not be deleted.
  #
  # Used internally to delete a job, allowing the beanstalkd pool to be reset.
  #
  # strategy.delete_job(job)
  #   #=> true
  def delete_job
    raise NotImplementedError
  end


  # :call-seq:
  #   job_matches?(job, options => {Symbol,String => Numeric,Proc,Range,Regexp,String}) => Boolean
  #
  # Returns a boolean indicating whether or not the provided +job+ matches the
  # given Hash of +options. Each _key_ in +options+ is a String or a Symbol that
  # identifies an attribute of +job+ that the corresponding _value_ should be
  # compared against. True is returned if every _value_ in +options+ evaluates to
  # true when compared to the attribute of +job+ identified by the corresponding
  # _key_. False is returned if any of the comparisons evaluates to false.
  #
  # If no options are given, returns true for any job that exists at the time of
  # evaluation.
  #
  # Each attribute comparison is performed using the triple equal (===)
  # operator/method of _value_ with the attribute of +job+ identified by _key_
  # passed into the method. Use of === allows for more complex comparisons
  # using Procs, Ranges, Regexps, etc.
  #
  # Consult MATCHABLE_JOB_ATTRIBUTES for a list of which attributes of +job+
  # can be matched against.
  #
  # Used internally to evaluate if a job matches an assertion.
  #
  #   strategy.job_matches?(reserved_job, :state => 'reserved')
  #     #=> true
  #
  #   strategy.job_matches(small_job, :body => lambda {|body| body.length > 50 })
  #     #=> false
  #
  #   strategy.job_matches(unreliable_job, :buries => 6..100)
  #     #=> true
  def job_matches?
    raise NotImplementedError
  end


  # :call-seq:
  #   jobs() => Enumerator
  #
  # Returns an Enumerator providing a means to enumerate all jobs in the beanstalkd
  # pool.
  #
  # Used internally to enumerate all jobs to find jobs matching an assertion.
  def jobs
    raise NotImplementedError
  end


  # :call-seq:
  #   pretty_print_job(job) => String
  #
  # Returns a String representation of +job+ in a pretty, human readable
  # format.
  #
  # Used internally to print a job when an assertion fails.
  def pretty_print_job
    raise NotImplementedError
  end


  # :call-seq:
  #   pretty_print_tube(tube) => String
  #
  # Returns a String representation of the tube in a pretty, human readable
  # format. Used internally to print a tube when an assertion fails.
  #
  # Used internally to print a tube when an assertion fails.
  def pretty_print_tube
    raise NotImplementedError
  end


  # :call-seq:
  #   tube_matches?(tube, options => {Symbol,String => Numeric,Proc,Range,Regexp,String}) => Boolean
  #
  # Returns a boolean indicating whether or not the provided +tube+ matches the
  # given Hash of +options. Each _key_ in +options+ is a String or a Symbol that
  # identifies an attribute of +tube+ that the corresponding _value_ should be
  # compared against. True is returned if every _value_ in +options+ evaluates to
  # true when compared to the attribute of +tube+ identified by the corresponding
  # _key_. False is returned if any of the comparisons evaluates to false.
  #
  # If no options are given, returns true for any tube that exists at the time of
  # evaluation.
  #
  # Each attribute comparison is performed using the triple equal (===)
  # operator/method of _value_ with the attribute of +job+ identified by _key_
  # passed into the method. Use of === allows for more complex comparisons using
  # Procs, Ranges, Regexps, etc.
  #
  # Consult MATCHABLE_TUBE_ATTRIBUTES for a list of which attributes of +tube+
  # can be matched against.
  #
  # Used internally to evaluate if a tube matches an assertion.
  #
  #   strategy.tube_matches?(paused_tube, :state => 'paused')
  #     #=> true
  #
  #   strategy.tube_matches(test_tube, :name => /test/)
  #     #=> true
  #
  #   strategy.tube_matches(backed_up_tube, 'current-jobs-ready' => 50..100)
  #     #=> true
  def tube_matches?
    raise NotImplementedError
  end


  # :call-seq:
  #   tubes() => Enumerator
  #
  # Returns an Enumerator providing a means to enumerate all tubes in the beanstalkd
  # pool.
  #
  # Used internally to enumerate all tubes to find tubes matching an assertion.
  def tubes
    raise NotImplementedError
  end

end
