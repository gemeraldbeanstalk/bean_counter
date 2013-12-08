class BeanCounter::TubeExpectation

  extend Forwardable

  def_delegators BeanCounter, :strategy

  # The value that the expectation expects
  attr_reader :expected

  # The tube found by the expecation during matching
  attr_reader :found


  # Builds the failure message used in the event of a positive expectation
  # failure
  def failure_message
    return '' unless found.nil?
    return "expected tube matching #{expected.to_s}, found none."
  end


  # Create a new tube expectation. Uses the given +expected+ Hash to determine
  # if any tubes exist that match the expected options.
  #
  # Each _key_ in the +expected+ Hash is a String or a Symbol that identifies
  # an attribute of a tube that the corresponding _value_ should be compared
  # against. All attribute comparisons are performed using the triple equal
  # (===) operator/method of the given _value_.
  #
  # See BeanCounter::MiniTest and/or BeanCounter::RSpec for more information.
  def initialize(expected)
    @expected = expected
  end


  # Checks all tubes in the beanstalkd pool for a tube matching the expected
  # options hash given at instantiation. The expectation succeeds if any tube
  # exists that matches all of the expected options. If no tube exists
  # matching all of the given options, the expectation fails.
  #
  # See Strategy#tube_matches? and/or the #tube_matches? method of the strategy
  # in use for more detailed information on how it is determined whether or not
  # a tube matches the options expected.
  #
  # See also BeanCounter::MiniTest and/or BeanCounter::RSpec for additional
  # information.
  def matches?(given = nil)
    @found = strategy.tubes.detect do |tube|
      strategy.tube_matches?(tube, expected)
    end

    return !found.nil?
  end


  # Builds the failure message used in the event of a negative expectation
  # failure
  def negative_failure_message
    return '' if found.nil?
    return [
      "expected no tubes matching #{expected.to_s},",
      "found #{strategy.pretty_print_tube(found)}",
    ].join(' ')
  end

end
