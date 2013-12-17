class BeanCounter::TubeExpectation

  extend Forwardable

  def_delegators BeanCounter, :strategy

  # The Hash of options given at instantiation that the expectation expects when
  # matching.
  # @return [Hash]
  attr_reader :expected

  # The tube found by the expecation during matching if one exists.
  # @return [Strategy::Tube]
  attr_reader :found


  # Builds the failure message used in the event of a positive expectation
  # failure.
  #
  # @return [String] the failure message to be used in the event of a positive
  #   expectation failure.
  def failure_message
    return '' unless found.nil?
    return "expected tube matching #{expected.to_s}, found none."
  end


  # Creates a new tube expectation. Uses the given `expected` Hash to determine
  # if any tubes exist that match the expected options.
  #
  # Each `key` in the `expected` Hash is a String or a Symbol that identifies
  # an attribute of a tube that the corresponding `value` should be compared
  # against. All attribute comparisons are performed using the triple-equal
  # (===) operator/method of the given `value`.
  #
  # See {BeanCounter::Strategy::MATCHABLE_TUBE_ASSERTIONS} for a list of those
  # attributes that can be used when matching.
  #
  # See {BeanCounter::TestAssertions} and/or {BeanCounter::SpecMatchers} for more
  # information.
  #
  # @see BeanCounter::Strategy::MATCHABLE_TUBE_ATTRIBUTES
  # @see BeanCounter::TestAssertions
  # @see BeanCounter::SpecMatchers
  # @param expected
  #   [Hash{String, Symbol => Numeric, Proc, Range, Regexp, String, Symbol}]
  #   Options expected when evaluating match.
  def initialize(expected)
    @expected = expected
  end


  # Checks all tubes in the Beanstalkd pool for a tube matching the expected
  # options hash given during instantiation. The expectation succeeds if any
  # tube exists that matches all of the expected options. If no tube exists
  # matching all of the given options, the expectation fails.
  #
  # See {BeanCounter::Strategy::MATCHABLE_TUBE_ATTRIBUTES} for a list of those
  # attributes that can be used when matching.
  #
  # See {BeanCounter::Strategy#tube_matches?} and/or the #tube_matches? method
  # of the strategy in use for more detailed information on how it is determined
  # whether or not a tube matches the options expected.
  #
  # See also {BeanCounter::TestAssertions} and/or {BeanCounter::SpecMatchers}
  # for additional information.
  #
  # @see BeanCounter::Strategy::MATCHABLE_TUBE_ATTRIBUTES
  # @see BeanCounter::TestAssertions
  # @see BeanCounter::SpecMatchers
  # @param given [Object] ignored. All expectations should be included in
  #   the expected options given at instantiation. Nothing will be infered
  #   from the given Object.
  # @return [Boolean] If a tube matching the expectation is found, returns true.
  #   Otherwise, returns false.
  def matches?(given = nil)
    @found = strategy.tubes.detect do |tube|
      strategy.tube_matches?(tube, expected)
    end

    return !found.nil?
  end


  # Builds the failure message used in the event of a negative expectation
  # failure.
  #
  # @return [String] the message to be used in the event of a negative
  #   expectation failure.
  def negative_failure_message
    return '' if found.nil?
    return [
      "expected no tubes matching #{expected.to_s},",
      "found #{strategy.pretty_print_tube(found)}",
    ].join(' ')
  end

end
