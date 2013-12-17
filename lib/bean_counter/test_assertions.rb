module BeanCounter::TestAssertions

  # Asserts that some number of jobs are enqueued that match the given Hash of
  # `options`. If no `options` are given, asserts that at least one job exists.
  #
  # Each `key` in `options` is a String or a Symbol that identifies an attribute
  # of a job that the corresponding `value` should be compared against. All attribute
  # comparisons are performed using the triple-equal (===) operator/method of
  # the given `value`.
  #
  # `options` may additionally include a `count` key ('count' or :count) that
  # can be used to assert that a particular number of matching jobs are found.
  #
  # If no `count` option is provided, the assertion succeeds if any job is found
  # that matches all of the `options` given. If no jobs are found that match the
  # `options` given, the assertion fails.
  #
  # If a `count` option is provided the assertion only succeeds if the triple-equal
  # (===) operator/method of the value of `count` evaluates to true when given the
  # total number of matching jobs. Otherwise the assertion fails. The use of ===
  # allows for more advanced comparisons using Procs, Ranges, Regexps, etc.
  #
  # See {BeanCounter::Strategy::MATCHABLE_JOB_ATTRIBUTES} for a list of what
  # attributes can be used when matching.
  #
  # See {BeanCounter::Strategy#job_matches?} and/or the #job_matches? method of
  # the strategy in use for more detailed information on how it is determined
  # whether or not a job matches the given `options`.
  #
  # @see BeanCounter::Strategy::MATCHABLE_JOB_ATTRIBUTES
  # @see BeanCounter::Strategy#job_matches?
  # @param options
  #   [Hash{String, Symbol => Numeric, Proc, Range, Regexp, String, Symbol}]
  #   Options expected when evaluating match assertion.
  # @option options [Numeric, Range] :count (nil) A particular number of matching
  #   jobs expected
  # @return [true] if the assertion succeeds
  # @example
  #   assert_enqueued
  #
  #   assert_enqueued(:body => /test/, :count => 5)
  #
  #   assert_enqueued('state' => 'buried', 'count' => 3)
  def assert_enqueued(options = {})
    enqueue_expectation(:assert, options)
  end


  # Asserts that the provided `block` enqueues some number of jobs that match
  # the given Hash of `options`. If no `options` are given, asserts that at
  # least one job is enqueued during the execution of the `block`.
  #
  # Unlike {#assert_enqueued}, which will evaluate all jobs in the Beanstalkd pool,
  # this method will only evaluate jobs that were enqueued during the
  # execution of the given `block`. This can be useful for performance and for
  # making assertions that could return false positives if all jobs were
  # evaluated.
  #
  # Each `key` in `options` is a String or a Symbol that identifies an attribute
  # of a job that the corresponding `value` should be compared against. All attribute
  # comparisons are performed using the triple-equal (===) operator/method of
  # the given `value`.
  #
  # `options` may additionally include a `count` key ('count' or :count) that
  # can be used to assert that a particular number of matching jobs are found.
  #
  # If no `count` option is provided, the assertion succeeds if any job is found
  # that matches all of the `options` given. If no jobs are found that match the
  # `options` given, the assertion fails.
  #
  # If a `count` option is provided the assertion only succeeds if the triple-equal
  # (===) operator/method of the value of `count` evaluates to true when given the
  # total number of matching jobs. Otherwise the assertion fails. The use of ===
  # allows for more advanced comparisons using Procs, Ranges, Regexps, etc.
  #
  # See {BeanCounter::Strategy::MATCHABLE_JOB_ATTRIBUTES} for a list of what
  # attributes can be used when matching.
  #
  # See {BeanCounter::Strategy#job_matches?} and/or the #job_matches? method of
  # the strategy in use for more detailed information on how it is determined
  # whether or not a job matches the given `options`.
  #
  # @see BeanCounter::Strategy::MATCHABLE_JOB_ATTRIBUTES
  # @see BeanCounter::Strategy#job_matches?
  # @param options
  #   [Hash{String, Symbol => Numeric, Proc, Range, Regexp, String, Symbol}]
  #   Options expected when evaluating match assertion.
  # @option options [Numeric, Range] :count (nil) A particular number of matching
  #   jobs expected
  # @yield No value is yielded to the provided block.
  # @raise [ArgumentError] if no block is given.
  # @return [true] if the assertion succeeds
  # @example
  #   assert_enqueues(:body => /test/) do
  #     enqueue_some_jobs
  #   end
  def assert_enqueues(options = {})
    raise ArgumentError, 'Block required' unless block_given?

    enqueue_expectation(:assert, options, &Proc.new)
  end


  # Asserts that at least one tube exist that matches the given Hash of
  # `options`. If no `options` are given, asserts that at least one tube exists,
  # which will always succeed.
  #
  # Each `key` in `options` is a String or a Symbol that identifies an attribute
  # of a tube that the corresponding `value` should be compared against. All attribute
  # comparisons are performed using the triple-equal (===) operator/method of
  # the given `value`.
  #
  # The assertion succeeds if any tube exists that matches all of the given
  # `options`. If no tube exists matching all of the given `options`, the assertion
  # fails.
  #
  # See {BeanCounter::Strategy::MATCHABLE_TUBE_ATTRIBUTES} for a list of those
  # attributes that can be used when matching.
  #
  # See {BeanCounter::Strategy#tube_matches?} and/or the #tube_matches? method of
  # the strategy in use for more detailed information on how it is determined
  # whether or not a tube matches the given `options`.
  #
  # @see BeanCounter::Strategy::MATCHABLE_TUBE_ATTRIBUTES
  # @see BeanCounter::Strategy#tube_matches?
  # @param options [Hash{Symbol, String => Numeric, Proc, Range, Regexp, String, Symbol}]
  #   Options expected when evaluating match assertion.
  # @return [true] if the assertion succeeds
  # @example
  #   assert_tube
  #
  #   assert_tube(:name => /test/)
  #
  #   assert_tube('current-jobs-ready' => 1..10)
  def assert_tube(options = {})
    tube_expectation(:assert, :failure_message, options)
  end


  # Asserts that no jobs are enqueued that match the given Hash of `options`.
  # If no `options` are given, asserts that no jobs exist.
  #
  # Each `key` in `options` is a String or a Symbol that identifies an attribute
  # of a job that the corresponding `value` should be compared against. All attribute
  # comparisons are performed using the triple-equal (===) operator/method of
  # the given `value`.
  #
  # The refutation succeeds if no jobs are found that match all of the `options`
  # given. If any matching jobs are found, the refutation fails.
  #
  # See {BeanCounter::Strategy::MATCHABLE_JOB_ATTRIBUTES} for a list of what
  # attributes can be used when matching.
  #
  # See {BeanCounter::Strategy#job_matches?} and/or the #job_matches? method of
  # the strategy in use for more detailed information on how it is determined
  # whether or not a job matches the given `options`.
  #
  # @see BeanCounter::Strategy::MATCHABLE_JOB_ATTRIBUTES
  # @see BeanCounter::Strategy#job_matches?
  # @param options
  #   [Hash{String, Symbol => Numeric, Proc, Range, Regexp, String, Symbol}]
  #   Options expected when evaluating match assertion.
  # @return [false] if the refutation succeeds
  # @example
  #   refute_enqueued
  #
  #   refute_enqueued(:body => lambda {|body| body.length > 50})
  #
  #   refute_enqueued('state' => 'buried')
  def refute_enqueued(options = {})
    enqueue_expectation(:refute, options)
  end


  # Asserts that the given `block` enqueues no jobs that match the given Hash
  # of `options`. If no `options` are given, asserts that no job are enqueued
  # by the given `block`.
  #
  # Unlike {#refute_enqueued}, which will evaluate all jobs in the beanstalkd pool,
  # this method will only evaluate jobs that were enqueued during the
  # execution of the given `block`. This can be useful for performance and for
  # making assertions that could return false positives if all jobs were
  # evaluated.
  #
  # Each `key` in `options` is a String or a Symbol that identifies an attribute
  # of a job that the corresponding `value` should be compared against. All attribute
  # comparisons are performed using the triple-equal (===) operator/method of
  # the given `value`.
  #
  # The refutation succeeds if no jobs are found that match all of the `options`
  # given. If any matching jobs are found, the refutation fails.
  #
  # See {BeanCounter::Strategy::MATCHABLE_JOB_ATTRIBUTES} for a list of what
  # attributes can be used when matching.
  #
  # See {BeanCounter::Strategy#job_matches?} and/or the #job_matches? method of
  # the strategy in use for more detailed information on how it is determined
  # whether or not a job matches the given `options`.
  #
  # @see BeanCounter::Strategy::MATCHABLE_JOB_ATTRIBUTES
  # @see BeanCounter::Strategy#job_matches?
  # @param options
  #   [Hash{String, Symbol => Numeric, Proc, Range, Regexp, String, Symbol}]
  #   Options expected when evaluating match assertion.
  # @yield The provided block is given no parameters.
  # @return [false] if the refutation succeeds
  # @example
  #   refute_enqueues do
  #     do_some_work_that_should_not_enqueue_any_jobs
  #   end
  def refute_enqueues(options = {})
    raise ArgumentError, 'Block required' unless block_given?

    enqueue_expectation(:refute, options, &Proc.new)
  end


  # Asserts that no tube exist that matches the given Hash of `options`.
  # If no options are given, asserts that no tubes exist which will always fail.
  #
  # Each `key` in `options` is a String or a Symbol that identifies an attribute
  # of a tube that the corresponding `value` should be compared against. All attribute
  # comparisons are performed using the triple-equal (===) operator/method of
  # the given `value`.
  #
  # The refutation succeeds if no tube exists that matches all of the given
  # `options`. If any tubes exist that match all of the given `options`, the
  # refutation fails.
  #
  # See {BeanCounter::Strategy::MATCHABLE_TUBE_ATTRIBUTES} for a list of those
  # attributes that can be used when matching.
  #
  # See {BeanCounter::Strategy#tube_matches?} and/or the #tube_matches? method of the strategy
  # in use for more detailed information on how it is determined whether or not
  # a tube matches the given `options`.
  #
  # @see BeanCounter::Strategy::MATCHABLE_TUBE_ATTRIBUTES
  # @see BeanCounter::Strategy#job_matches?
  # @param options
  #   [Hash{String, Symbol => Numeric, Proc, Range, Regexp, String, Symbol}]
  #   Options expected when evaluating match assertion.
  # @option options [Numeric, Range] :count (nil) A particular number of matching
  #   jobs expected
  # @return [false] if the refutation succeeds
  # @example
  #   refute_tube
  #     #=> always fails
  #
  #   refute_tube(:name => /production/)
  #
  #   refute_tube('current-jobs-ready' => 0)
  def refute_tube(options = {})
    tube_expectation(:refute, :negative_failure_message, options)
  end

  private


  # Builds job expectation object, evaluates, and makes appropriate assertion
  # with appropriate failure message.
  def enqueue_expectation(assertion_method, options, &block)
    message_type = assertion_method == :assert ? :failure_message : :negative_failure_message
    expectation = BeanCounter::EnqueuedExpectation.new(options)
    match = expectation.matches?(block_given? ? block : nil)
    send(assertion_method, match, expectation.send(message_type))
  end


  # Builds tube expectation object, evaluates, and makes appropriate assertion
  # with appropriate failure message.
  def tube_expectation(assertion_method, message_type, options)
    expectation = BeanCounter::TubeExpectation.new(options)
    match = expectation.matches?
    send(assertion_method, match, expectation.send(message_type))
  end

end
