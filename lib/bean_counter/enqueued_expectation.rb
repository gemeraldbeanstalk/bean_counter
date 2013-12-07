class BeanCounter::EnqueuedExpectation

  extend Forwardable

  def_delegators BeanCounter, :strategy

  # The value that the expectation expects
  attr_reader :expected

  # The number of matching jobs the expectation expects
  attr_reader :expected_count

  # The jobs found by the expecation during matching
  attr_reader :found


  # Iterates over the provided collection searching for jobs matching the
  # Hash of expected options provided at instantiation.
  def collection_matcher(collection)
    @found = collection.send(expected_count? ? :select : :detect) do |job|
      strategy.job_matches?(job, expected)
    end

    expected_count? ? expected_count === found.length : !found.nil?
  end


  # Returns a Boolean indicating whether a specific number of jobs are expected.
  def expected_count?
    return !!expected_count
  end


  # Builds the failure message used in the event of a positive expectation
  # failure
  def failure_message
    if found.kind_of?(Array)
      found_count = "#{found.length}:"
      found_string = found.map {|job| strategy.pretty_print_job(job) }.join("\n")
    else
      found_count = 'none.'
      found_string = ''
    end
    [
      "expected #{expected_count || 'any number of'} jobs matching #{expected.to_s},",
      "found #{found_count}",
       found_string,
    ].join(' ')
  end


  # Create a new enqueued expectation. Uses the given +expected+ Hash to determine
  # if any jobs are enqueued that match the expected options.
  #
  # Each _key_ in +expected+ is a String or a Symbol that identifies an attribute
  # of a job that the corresponding _value_ should be compared against. All attribute
  # comparisons are performed using the triple equal (===) operator/method of
  # the given _value_.
  #
  # +expected+ may additionally include a _count_ key of 'count' or :count that
  # can be used to specify that a particular number of matching jobs are found.
  #
  # See BeanCounter::MiniTest and/or BeanCounter::RSpec for more information.
  def initialize(expected)
    @expected = expected
    @expected_count = [expected.delete(:count), expected.delete('count')].compact.first
  end


  # Checks the beanstalkd pool for jobs matching the Hash of expected options
  # provided at instantiation.
  #
  # If no _count_ option is provided, the expectation succeeds if any job is found
  # that matches all of the expected options. If no jobs are found that match the
  # expected options, the expecation fails.
  #
  # If a _count_ option is provided the expectation only succeeds if the triple equal
  # (===) operator/method of the value of _count_ evaluates to true when given the
  # total number of matching jobs. Otherwise the expecation fails. The use of ===
  # allows for more advanced comparisons using Procs, Ranges, Regexps, etc.
  #
  # See Strategy#job_matches? and/or the #job_matches? method of the strategy
  # in use for more detailed information on how it is determined whether or not
  # a job matches the options expected.
  #
  # See also BeanCounter::MiniTest and/or BeanCounter::RSpec for additional
  # information.
  def matches?(given = nil)
    if given.nil?
      collection_matcher(strategy.jobs)
    elsif given.kind_of?(Proc)
      proc_matcher(given)
    else
      raise ArgumentError, "Can't do something"
    end
  end


  # Builds the failure message used in the event of a negative expectation
  # failure
  def negative_failure_message
    if found.nil?
      return ''
    elsif found.kind_of?(Array)
      found_count = found.length
      found_string = found.map {|job| strategy.pretty_print_job(job) }.join("\n")
    else
      found_count = 1
      found_string = strategy.pretty_print_job(found)
    end
    return [
      "expected no jobs matching #{expected.to_s},",
      "found #{found_count}:",
       found_string,
    ].join(' ')
  end


  # Monitors the beanstalkd pool for new jobs enqueued during the provided
  # block than passes any collected jobs to the collection matcher to determine
  # if any jobs were enqueued that match the expected options provided at
  # instantiation
  def proc_matcher(block)
    new_jobs = strategy.collect_new_jobs(&block)
    collection_matcher(new_jobs)
  end

end
