module BeanCounter

  # Use StalkClimberStrategy by default because it works with standard Beanstalkd
  DEFAULT_STRATEGY = :'BeanCounter::Strategy::StalkClimberStrategy'

  # Sets the Beanstalkd server URLs to be used by BeanCounter.
  #
  # @param value [String, Array<String>] The new value to to assign to beanstalkd_urls
  # @return [Object] Returns the value given
  def self.beanstalkd_url=(value)
    @beanstalkd_url = value
  end

  # Returns an Array of parsed Beanstalkd URLs.
  # Server URLs provided via the environment variable `BEANSTALKD_URL` are given
  # precedence. When setting beanstalkd_url from the environment, urls are
  # expected in a comma separated list. If `ENV['BEANSTALKD_URL']` is not set,
  # the BeanCounter.beanstalkd_url instance variable is checked and parsed next.
  # Finally, if the BeanCounter.beanstalkd_url instance variable has not been
  # set, the configuration for Beaneater is checked and parsed. If no
  # beanstalkd_url can be determined a RuntimeError is raised.
  # Beanstalkd URLs can be provided in any of three supported formats shown in
  # in the examples below.
  #
  # In short, a host is the only required component. If no port is provided, the default
  # beanstalkd port of 11300 is assumed. If a URI scheme other than beanstalk
  # is provided the strategy in use will likely raise an error.
  #
  # @return [Array<String>] An Array of Beanstalkd URLs.
  # @example Valid beanstalkd_url formats
  #   # host only:
  #   'localhost'
  #
  #   # host and port:
  #   '192.168.1.100:11300'
  #
  #   # host and port prefixed by beanstalk URI scheme:
  #   'beanstalk://127.0.0.1:11300'
  #
  # @example BeanCounter.beanstalkd_url provided via ENV['BEANSTALKD_URL']
  #   # $ BEANSTALKD_URL='127.0.0.1,beanstalk://localhost:11300,localhost:11301' rake test
  #
  #   BeanCounter.beanstalkd_url
  #     #=> ['127.0.0.1', 'beanstalk://localhost:11300', 'localhost:11301']
  #
  # @example BeanCounter.beanstalkd_url set explicitly
  #   BeanCounter.beanstalkd_url = 'beanstalk://localhost'
  #   BeanCounter.beanstalkd_url
  #     #=> 'beanstalk://localhost'
  #
  # @example BeanCounter.beanstalkd_url provided by Beaneater
  #   Beaneater.configure do |config|
  #     config.beanstalkd_url = ['localhost', 'localhost:11301']
  #   end
  #
  #   BeanCounter.beanstalkd_url
  #     #=> ['localhost', 'localhost:11301']
  def self.beanstalkd_url
    @hosts_from_env = ENV['BEANSTALKD_URL']
    @hosts_from_env = @hosts_from_env.split(',').map!(&:strip) unless @hosts_from_env.nil?
    beanstalkd_url = @hosts_from_env || @beanstalkd_url || Beaneater.configuration.beanstalkd_url
    raise 'Could not determine beanstalkd url' if beanstalkd_url.to_s == ''
    return beanstalkd_url.is_a?(Array) ? beanstalkd_url : [beanstalkd_url]
  end


  # Returns a previously materialized strategy or materializes a new default
  # strategy for use.
  #
  # See {BeanCounter::Strategy.materialize_strategy} for more information on the
  # materialization process.
  #
  # @see BeanCounter::Strategy.materialize_strategy
  # @return [BeanCounter::Strategy] An existing or newly materialized default strategy
  def self.default_strategy
    return @default_strategy ||= BeanCounter::Strategy.materialize_strategy(DEFAULT_STRATEGY)
  end


  # Uses strategy to delete all jobs from the beanstalkd pool or from the tube
  #   specified by `tube_name`.
  #
  # It should be noted that jobs that are reserved can only be deleted by the
  # reserving connection and thus cannot be deleted via this method. As such,
  # care may need to be taken to ensure that jobs are not left in a reserved
  # state.
  #
  # @param tube_name [String] a particular tube to clear all jobs from. If not
  #   given, all jobs in the Beanstalkd pool will be} deleted.
  # @return [Boolean] Returns true if all encountered jobs were deleted successfully. Returns
  #   false if any of the jobs enumerated could not be deleted.
  def self.reset!(tube_name = nil)
    partial_failure = false
    strategy.jobs.each do |job|
      success = strategy.delete_job(job) if tube_name.nil? || strategy.job_matches?(job, :tube => tube_name)
      partial_failure ||= success
    end
    return !partial_failure
  end


  # Returns a list of known subclasses of BeanCounter::Strategy. Typically this
  # list represents the strategies available for interacting with Beanstalkd.
  #
  # @return [Array<BeanCounter::Strategy>] Returns a list of known subclasses of
  #   BeanCounter::Strategy
  def self.strategies
    return BeanCounter::Strategy.strategies
  end


  # Sets the strategy that BeanCounter should use when interacting with Beanstalkd.
  # The value provided for `strategy_identifier` will be used to
  # materialize an instance of the matching strategy class. If the provided
  # `strategy_identifier` is nil, any existing strategy will be cleared and
  # the next call to BeanCounter.strategy will use the default strategy.
  #
  # @param strategy_identifier [Object] A class or an Object that responds to
  #   :to_sym identifying the subclass of BeanCounter::Strategy to use
  #   when communicating with the beanstalkd pool
  # @return [Object] Returns the value given
  def self.strategy=(strategy_identifier)
    if strategy_identifier.nil?
      @strategy = nil
    else
      @strategy = BeanCounter::Strategy.materialize_strategy(strategy_identifier).new
    end
  end


  # Returns a previously materialized strategy or instantiates a new instance
  # of the default strategy. If no previous strategy exists, a new instance of
  # the default strategy is instantiated and returned.
  #
  # @return [BeanCounter::Strategy] Returns the existing strategy or a new
  #   instance of the default strategy
  def self.strategy
    return @strategy ||= default_strategy.new
  end

end
