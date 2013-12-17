class BeanCounter::EnqueuedExpectation

  extend Forwardable

  def_delegators BeanCounter, :strategy

  # The Hash of options given at instantiation that the expectation expects when
  # matching.
  # @return [Hash]
  attr_reader :expected

  # The number of matching jobs the expectation expects
  # @return [Numeric, Range]
  attr_reader :expected_count

  # The jobs found by the expecation during matching
  # @return [Array<Strategy::Job>]
  attr_reader :found


  # Iterates over the provided collection searching for jobs matching the
  # Hash of expected options provided during instantiation.
  #
  # @param collection [Array<Strategy::Job>] A collection of jobs as
  #   implemented by the strategy to evaluate for a match.
  # @return [Boolean] true if the collection matches the expected options and
  #   count
  def collection_matcher(collection)
    @found = collection.send(expected_count? ? :select : :detect) do |job|
      strategy.job_matches?(job, expected)
    end

    @found = [@found] unless expected_count? || @found.nil?

    expected_count? ? expected_count === found.to_a.length : !found.nil?
  end


  # Returns a Boolean indicating whether a specific number of jobs are expected.
  #
  # @return [Boolean] true if a specifc number of jobs are expected, otherwise
  #   false
  def expected_count?
    return !!expected_count
  end


  # Builds the failure message used in the event of a positive expectation
  # failure.
  #
  # @return [String] The failure message for use in the event of a positive
  #   expectation failure.
  def failure_message
    if found.nil?
      found_count = 'none'
      found_string = nil
    else
      materialized_found = found.to_a
      found_count = "#{materialized_found.length}:"
      found_string = materialized_found.map {|job| strategy.pretty_print_job(job) }.join("\n")
    end
    [
      "expected #{expected_count || 'any number of'} jobs matching #{expected.to_s},",
      "found #{found_count}",
      found_string,
    ].compact.join(' ')
  end


  # Create a new enqueued expectation. Uses the given `expected` Hash to determine
  # if any jobs are enqueued that match the expected options.
  #
  # Each `key` in `expected` is a String or a Symbol that identifies an attribute
  # of a job that the corresponding `value` should be compared against. All attribute
  # comparisons are performed using the triple-equal (===) operator/method of
  # the given `value`.
  #
  # `expected` may additionally include a `count` key of 'count' or :count that
  # can be used to specify that a particular number of matching jobs are found.
  #
  # See {BeanCounter::Strategy::MATCHABLE_JOB_ATTRIBUTES} for a list of
  #   attributes that can be used when matching.
  #
  # @see BeanCounter::Strategy::MATCHABLE_JOB_ATTRIBUTES
  # @see BeanCounter::TestAssertions
  # @see BeanCounter::SpecMatchers
  # @param expected
  #   [Hash{String, Symbol => Numeric, Proc, Range, Regexp, String, Symbol}]
  #   Options expected when evaluating match
  # @option expected [Numeric, Range] :count (nil) A particular number of matching
  #   jobs expected
  def initialize(expected)
    @expected = expected
    @expected_count = [expected.delete(:count), expected.delete('count')].compact.first
  end


  # Checks the beanstalkd pool for jobs matching the Hash of expected options
  # provided at instantiation.
  #
  # If no `count` option is provided, the expectation succeeds if any job is found
  # that matches all of the expected options. If no jobs are found that match the
  # expected options, the expecation fails.
  #
  # If a `count` option is provided the expectation only succeeds if the triple-equal
  # (===) operator/method of the value of `count` evaluates to true when given the
  # total number of matching jobs. Otherwise the expecation fails. The use of ===
  # allows for more advanced comparisons using Procs, Ranges, Regexps, etc.
  #
  # See Strategy#job_matches? and/or the #job_matches? method of the strategy
  # in use for more detailed information on how it is determined whether or not
  # a job matches the options expected.
  #
  # See {BeanCounter::Strategy::MATCHABLE_JOB_ATTRIBUTES} for a list of
  #   attributes that can be used when matching.
  #
  # @see BeanCounter::Strategy::MATCHABLE_JOB_ATTRIBUTES
  # @see BeanCounter::TestAssertions
  # @see BeanCounter::SpecMatchers
  # @param given [Proc] If a Proc is provided, only jobs enqueued during the
  #   execution of the Proc are considered when looking for a match. Otherwise
  #   all jobs available to the strategy will be evaluated for a match.
  # @return [Boolean] If a match is found, returns true. Otherwise, returns
  #   false.
  def matches?(given = nil)
    if given.kind_of?(Proc)
      return proc_matcher(given)
    else
      return collection_matcher(strategy.jobs)
    end
  end


  # Builds the failure message used in the event of a negative expectation
  # failure
  #
  # @return [String] The failure message for use in the event of a negative
  #   expectation failure.
  def negative_failure_message
    return '' if found.nil? || found == []

    found_count = found.length
    found_string = found.map {|job| strategy.pretty_print_job(job) }.join("\n")
    if expected_count?
      job_count = expected_count
      job_word = expected_count == 1 ? 'job' : 'jobs'
    else
      job_count = 'any'
      job_word = 'jobs'
    end
    return [
      "did not expect #{job_count} #{job_word} matching #{expected.to_s},",
      "found #{found_count}:",
       found_string,
    ].join(' ')
  end


  # Evaluates jobs enqueued during the execution of the provided block to
  # determine if any jobs were enqueued that match the expected options provided
  # at instantiation
  #
  # @param block [Proc] A Proc that when executed should demonstrate that
  #   expected behavior.
  # @return [Boolean] If the jobs enqueued during the execution of the `block`
  #   include a match, returns true. Otherwise, returns false.
  def proc_matcher(block)
    new_jobs = strategy.collect_new_jobs(&block)
    return collection_matcher(new_jobs)
  end

end
