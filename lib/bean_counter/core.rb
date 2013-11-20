module BeanCounter

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

end
