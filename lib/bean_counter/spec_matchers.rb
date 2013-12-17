module BeanCounter::SpecMatchers

  # Creates a new {BeanCounter::EnqueuedExpectation} with `expected` stored for
  # later use when matching. Most of the time the value provided for `expected`
  # will be ignored, the only exception is when `expected` is given a block.
  # When a block is provided for `expected`, only jobs enqueued during the
  # execution of the block will be considered when matching.
  #
  # See {BeanCounter::EnqueuedExpectation} for additional information and usage
  # patterns.
  #
  # @see BeanCounter::EnqueuedExpectation
  # @param expected
  #   [Hash{String, Symbol => Numeric, Proc, Range, Regexp, String, Symbol}]
  #   options used for evaluating match.
  # @return [BeanCounter::EnqueuedExpectation] an expectation to be used for
  #   matching.
  def have_enqueued(expected)
    BeanCounter::EnqueuedExpectation.new(expected)
  end

  # Creates a new {BeanCounter::TubeExpectation} with `expected` stored for
  # later use when matching. However, `expected` is never used when matching.
  # Instead, all tubes are matched against until a match is found.
  #
  # See {BeanCounter::TubeExpectation} for additional information and usage
  # patterns.
  #
  # @param expected
  #   [Hash{String, Symbol => Numeric, Proc, Range, Regexp, String, Symbol}]
  #   options used for evaluating match.
  # @see BeanCounter::TubeExpectation
  # @return [BeanCounter::TubeExpectation] an expectation to be used for matching.
  def have_tube(expected)
    BeanCounter::TubeExpectation.new(expected)
  end

end
