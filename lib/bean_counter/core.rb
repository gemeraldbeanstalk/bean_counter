module BeanCounter

  # Use StalkClimberStrategy by default because it works with standard Beanstalkd
  DEFAULT_STRATEGY = :'BeanCounter::Strategy::StalkClimberStrategy'

  class << self
    # Beanstalkd server urls to be used by BeanCounter
    attr_writer :beanstalkd_url
  end

  # :call-seq:
  #   beanstalkd_url() => Array[String]
  #
  # Returns an array of parsed beanstalkd urls.
  # Server urls provided via the environment variable +BEANSTALKD_URL+ are given
  # precedence. When setting beanstalkd_url from the environment, urls are
  # expected in a comma separated list. If ENV['BEANSTALKD_URL'] is not set
  # BeanCounter::beanstalkd_url is checked and parsed next. Finally, if
  # BeanCounter::beanstalkd_url has not been set, the configuration for Beaneater is
  # checked and parsed. If no beanstalkd_url can be determined a RuntimeError is raised.
  # URLs can be provided in any of three supported formats:
  # * localhost (host only)
  # * 192.168.1.100:11300 (host and port)
  # * beanstalk://127.0.0.1:11300 (host and port prefixed by beanstalk scheme)
  #
  # In short, a host is the only required component. If no port is provided, the default
  # beanstalkd port of 11300 is assumed. If a scheme other than beanstalk is provided
  # a StalkClimber::ConnectionPool::InvalidURIScheme error is raised.
  #
  #   $ BEANSTALKD_URL='127.0.0.1,beanstalk://localhost:11300,localhost:11301' rake test
  #   BeanCounter.beanstalkd_url
  #     #=> ['127.0.0.1', 'beanstalk://localhost:11300', 'localhost:11301']
  #
  #   BeanCounter.beanstalkd_url = 'beanstalk://localhost'
  #   BeanCounter.beanstalkd_url
  #     #=> 'beanstalk://localhost'
  #
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
    return beanstalkd_url
  end


  # :call-seq:
  #   default_strategy() => subclass of BeanCounter::Strategy
  #
  # Return a previously materialized default strategy or materialize a new default
  # strategy for use. See BeanCounter::Strategy::materialize_strategy for more
  # information on the materialization process.
  def self.default_strategy
    return @default_strategy ||= BeanCounter::Strategy.materialize_strategy(DEFAULT_STRATEGY)
  end


  # :call-seq:
  #   reset!(tube_name = nil) => Boolean
  # Uses the strategy to delete all jobs from the +tube_name+ tube. If +tube_name+
  # is not provided, all jobs on the beanstalkd server are deleted.
  #
  # It should be noted that jobs that are reserved can only be deleted by the
  # reserving connection and thus cannot be deleted via this method. As such,
  # care may need to be taken to ensure that jobs are not left in a reserved
  # state.
  #
  # Returns true if all encountered jobs were deleted successfully. Returns
  # false if any of the jobs enumerated could not be deleted.
  def self.reset!(tube_name = nil)
    partial_failure = false
    strategy.jobs.each do |job|
      success = strategy.delete_job(job) if tube_name.nil? || strategy.job_matches?(job, :tube => tube_name)
      partial_failure ||= success
    end
    return !partial_failure
  end


  # Returns a list of known subclasses of BeanCounter::Strategy.
  # Typically this list represents the strategies available for interacting
  # with beanstalkd.
  def self.strategies
    return BeanCounter::Strategy.strategies
  end


  # Sets the strategy that BeanCounter should use when interacting with
  # beanstalkd. The value provided for +strategy_identifier+ will be used to
  # materialize an instance of the matching strategy class. If the provided
  # +strategy_identifier+ is nil, any existing strategy will be cleared and
  # the next call to BeanCounter::strategy will use the default strategy.
  def self.strategy=(strategy_identifier)
    if strategy_identifier.nil?
      @strategy = nil
    else
      @strategy = BeanCounter::Strategy.materialize_strategy(strategy_identifier).new
    end
  end


  # Returns a previously materialized strategy if one exists. If no previous
  # strategy exists, a new instance of the default strategy is instantiated
  # and returned.
  def self.strategy
    return @strategy ||= default_strategy.new
  end

end
