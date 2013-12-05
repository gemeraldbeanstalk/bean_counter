module BeanCounter::MiniTest

  # :call-seq:
  #   assert_enqueued(options = {Symbol,String => Numeric,Proc,Range,Regexp,String})
  #
  # Asserts that some number of jobs are enqueued that match the given Hash of
  # +options+. If no +options+ are given, asserts that at least one job exists.
  #
  # Each _key_ in +options+ is a String or a Symbol that identifies an attribute
  # of a job that the corresponding _value_ should be compared against. All attribute
  # comparisons are performed using the triple equal (===) operator/method of
  # the given _value_.
  #
  # +options+ may additionally include a _count_ key of 'count' or :count that
  # can be used to assert that a particular number of matching jobs are found.
  #
  # If no _count_ option is provided, the assertion succeeds if any job is found
  # that matches all of the +options+ given. If no jobs are found that match the
  # +options+ given, the assertion fails.
  #
  # If a _count_ option is provided the assertion only succeeds if the triple equal
  # (===) operator/method of the value of _count_ evaluates to true when given the
  # total number of matching jobs. Otherwise the assertion fails. The use of ===
  # allows for more advanced comparisons using Procs, Ranges, Regexps, etc.
  #
  # See Strategy#job_matches? and/or the #job_matches? method of the strategy
  # in use for more detailed information on how it is determined whether or not
  # a job matches the given +options+.
  #
  #   assert_enqueued
  #
  #   assert_enqueued(:body => /test/, :count => 5)
  #
  #   assert_enqueued('state' => 'buried', 'count' => 3)
  def assert_enqueued(options = {})
    enqueue_assertion(strategy.jobs, options)
  end


  # :call-seq:
  #   assert_enqueues(options = {Symbol,String => Numeric,Proc,Range,Regexp,String}) { block }
  #
  # Asserts that the given +block+ enqueues some number of jobs that match the
  # given Hash of +options+. If no +options+ are given, asserts that at least
  # one job is enqueued during the execution of the +block+.
  #
  # Unlike #assert_enqueued, which will evaluate all jobs in the beanstalkd pool,
  # this method will only evaluate jobs that were enqueued during the
  # execution of the given +block+. This can be useful for performance and for
  # making assertions that could return false positives if all jobs were
  # evaluated.
  #
  # Each _key_ in +options+ is a String or a Symbol that identifies an attribute
  # of a job that the corresponding _value_ should be compared against. All attribute
  # comparisons are performed using the triple equal (===) operator/method of
  # the given _value_.
  #
  # +options+ may additionally include a _count_ key of 'count' or :count that
  # can be used to assert that a particular number of matching jobs are found.
  #
  # If no _count_ option is provided, the assertion succeeds if any job is found
  # that matches all of the +options+ given. If no jobs are found that match the
  # +options+ given, the assertion fails.
  #
  # If a _count_ option is provided the assertion only succeeds if the triple equal
  # (===) operator/method of the value of _count_ evaluates to true when given the
  # total number of matching jobs. Otherwise the assertion fails. The use of ===
  # allows for more advanced comparisons using Procs, Ranges, Regexps, etc.
  #
  # See Strategy#job_matches? and/or the #job_matches? method of the strategy
  # in use for more detailed information on how it is determined whether or not
  # a job matches the given +options+.
  #
  #   assert_enqueues(:body => /test/) do
  #     enqueue_some_jobs
  #   end
  def assert_enqueues(options = {})
    raise ArgumentError, 'Block required' unless block_given?

    found = strategy.collect_new_jobs { yield }
    enqueue_assertion(found, options)
  end


  # :call-seq:
  #   assert_tube(options = {Symbol,String => Numeric,Proc,Range,Regexp,String})
  #
  # Asserts that at least one tube exist that matches the given Hash of
  # +options+. If no +options+ are given, asserts that at least one tube exists,
  # which will always succeed.
  #
  # Each _key_ in +options+ is a String or a Symbol that identifies an attribute
  # of a tube that the corresponding _value_ should be compared against. All attribute
  # comparisons are performed using the triple equal (===) operator/method of
  # the given _value_.
  #
  # The assertion succeeds if any tube exists that matches all of the given
  # +options+. If no tube exists matching all of the given +options+, the assertion
  # fails.
  #
  # See Strategy#tube_matches? and/or the #tube_matches? method of the strategy
  # in use for more detailed information on how it is determined whether or not
  # a tube matches the given +options+.
  #
  #   assert_tube
  #
  #   assert_tube(:name => /test/)
  #
  #   assert_tube('current-jobs-ready' => 1..10)
  def assert_tube(options = {})
    match = strategy.tubes.any? do |tube|
      strategy.tube_matches?(tube, options)
    end
    assert match, "Assertion failed: No tubes found matching #{options.to_s}"
  end


  # :call-seq:
  #   refute_enqueued(options = {Symbol,String => Numeric,Proc,Range,Regexp,String})
  #
  # Asserts that no jobs are enqueued that match the given Hash of +options+.
  # If no +options+ are given, asserts that no jobs exist.
  #
  # Each _key_ in +options+ is a String or a Symbol that identifies an attribute
  # of a job that the corresponding _value_ should be compared against. All attribute
  # comparisons are performed using the triple equal (===) operator/method of
  # the given _value_.
  #
  # The refutation succeeds if no jobs are found that match all of the +options+
  # given. If any matching jobs are found, the refutation fails.
  #
  # See Strategy#job_matches? and/or the #job_matches? method of the strategy
  # in use for more detailed information on how it is determined whether or not
  # a job matches the given +options+.
  #
  #   refute_enqueued
  #
  #   refute_enqueued(:body => lambda {|body| body.length > 50})
  #
  #   refute_enqueued('state' => 'buried')
  def refute_enqueued(options = {})
    enqueue_refutation(strategy.jobs, options)
  end


  # :call-seq:
  #   refute_enqueues(options = {Symbol,String => Numeric,Proc,Range,Regexp,String}) { block }
  #
  # Asserts that the given +block+ enqueues no jobs that match the given Hash
  # of +options+. If no +options+ are given, asserts that no job are enqueued
  # by the given +block+.
  #
  # Unlike #refute_enqueued, which will evaluate all jobs in the beanstalkd pool,
  # this method will only evaluate jobs that were enqueued during the
  # execution of the given +block+. This can be useful for performance and for
  # making assertions that could return false positives if all jobs were
  # evaluated.
  #
  # Each _key_ in +options+ is a String or a Symbol that identifies an attribute
  # of a job that the corresponding _value_ should be compared against. All attribute
  # comparisons are performed using the triple equal (===) operator/method of
  # the given _value_.
  #
  # The refutation succeeds if no jobs are found that match all of the +options+
  # given. If any matching jobs are found, the refutation fails.
  #
  # See Strategy#job_matches? and/or the #job_matches? method of the strategy
  # in use for more detailed information on how it is determined whether or not
  # a job matches the given +options+.
  #
  #   refute_enqueues do
  #     do_some_work_that_should_not_enqueue_any_jobs
  #   end
  def refute_enqueues(options = {})
    raise ArgumentError, 'Block required' unless block_given?

    found = strategy.collect_new_jobs { yield }
    enqueue_refutation(found, options)
  end


  # :call-seq:
  #   refute_tube(options = {Symbol,String => Numeric,Proc,Range,Regexp,String})
  #
  # Asserts that no tube exist that matches the given Hash of +options+.
  # If no options are given, asserts that no tubes exist which will always fail.
  #
  # Each _key_ in +options+ is a String or a Symbol that identifies an attribute
  # of a tube that the corresponding _value_ should be compared against. All attribute
  # comparisons are performed using the triple equal (===) operator/method of
  # the given _value_.
  #
  # The refutation succeeds if no tube exists that matches all of the given
  # +options+. If any tubes exist that match all of the given +options+, the
  # refutation fails.
  #
  # See Strategy#tube_matches? and/or the #tube_matches? method of the strategy
  # in use for more detailed information on how it is determined whether or not
  # a tube matches the given +options+.
  #
  #   refute_tube
  #     #=> always fails
  #
  #   refute_tube(:name => /production/)
  #
  #   refute_tube('current-jobs-ready' => 0)
  def refute_tube(options = {})
    match = strategy.tubes.detect do |tube|
      strategy.tube_matches?(tube, options)
    end
    return assert(true) if match.nil?
    assert(
      false,
      [
        "Assertion failed: Expected no tubes matching #{options.to_s},",
        "found #{strategy.pretty_print_tube(match)}",
      ].join(' ')
    )
  end

  private


  # Method that actually evaluates if any matching jobs were found and makes
  # the appropriate assertion.
  def enqueue_assertion(collection, options)
    expected_count = options[:count] || options['count']
    found = collection.send(expected_count ? :select : :detect) do |job|
      strategy.job_matches?(job, options)
    end
    if expected_count
      assert(
        expected_count === found.length,
        [
          "Assertion failed: Expected #{expected_count} jobs matching #{options.to_s},",
          "found #{found.length}:",
          found.map { |job| strategy.pretty_print_job(job) }.join("\n") || '[]',
        ].join(' ')
     )
    else
      assert !found.nil?, "Assertion failed: No jobs found matching #{options.to_s}"
    end
  end


  # Method that actually verifies no matching jobs were found and makes the
  # appropriate assertion.
  def enqueue_refutation(collection, options)
    found = collection.detect do |job|
      strategy.job_matches?(job, options)
    end
    message = [
      "Assertion failed: Expected no jobs found matching #{options.to_s},",
      "found #{strategy.pretty_print_job(found)}",
    ].join(' ') unless found.nil?
    refute(found, message || '')
  end


  # Shortcut to BeanCounter strategy in use
  def strategy
    return BeanCounter.strategy
  end

end
