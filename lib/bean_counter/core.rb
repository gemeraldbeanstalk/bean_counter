module BeanCounter

  DEFAULT_STRATEGY = :'BeanCounter::Strategy::StalkClimberStrategy'

  class << self
    attr_writer :beanstalkd_url
  end

  # Adapted from Beaneater::Pool
  def self.beanstalkd_url
    @hosts_from_env = ENV['BEANSTALKD_URL']
    @hosts_from_env = @hosts_from_env.split(',').map!(&:strip) unless @hosts_from_env.nil?
    beanstalkd_url = @beanstalkd_url || @hosts_from_env || Beaneater.configuration.beanstalkd_url
    raise 'Could not determine beanstalkd url' if beanstalkd_url.to_s == ''
    return beanstalkd_url
  end


  def self.default_strategy
    return @default_strategy ||= BeanCounter::Strategy.materialize_strategy(DEFAULT_STRATEGY)
  end


  def self.reset!(tube_name = nil)
    strategy.jobs.each do |job|
      strategy.delete_job(job) if tube_name.nil? || strategy.job_matches?(job, :tube => tube_name)
    end
  end


  def self.strategies
    return BeanCounter::Strategy.strategies
  end


  def self.strategy=(strategy_identifier)
    if strategy_identifier.nil?
      @strategy = nil
    else
      @strategy = BeanCounter::Strategy.materialize_strategy(strategy_identifier).new
    end
  end


  def self.strategy
    return @strategy ||= default_strategy.new
  end

end
