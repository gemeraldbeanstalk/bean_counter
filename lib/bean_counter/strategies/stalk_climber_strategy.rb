require 'stalk_climber'

class BeanCounter::Strategy::StalkClimberStrategy < BeanCounter::Strategy

  extend Forwardable

  STATS_METHOD_NAMES = begin
    attrs = (
      BeanCounter::Strategy::MATCHABLE_JOB_ATTRIBUTES +
      BeanCounter::Strategy::MATCHABLE_TUBE_ATTRIBUTES
    ).map!(&:to_sym).uniq.sort
    method_names = attrs.map {|method| method.to_s.gsub(/-/, '_').to_sym }
    attr_methods = Hash[attrs.zip(method_names)]
    attr_methods[:pause] = :pause_time
    attr_methods
 end

  TEST_TUBE = 'bean_counter_stalk_climber_test'

  attr_writer :test_tube

  def_delegators :climber, :jobs, :tubes


  def collect_new_jobs
    raise ArgumentError, 'Block required' unless block_given?

    min_ids = climber.max_job_ids
    yield
    max_ids = climber.max_job_ids
    new_jobs = []
    min_ids.each do |connection, min_id|
      testable_ids = (min_id..max_ids[connection]).to_a
      new_jobs.concat(connection.fetch_jobs(testable_ids).compact)
    end
    return new_jobs
  end


  def delete_job(job)
    job.delete
    return true
  rescue Beaneater::NotFoundError
    return job.exists? ? false : true
  end


  def job_matches?(job, opts = {})
    return matcher(MATCHABLE_JOB_ATTRIBUTES, job, opts)
  end


  def pretty_print_job(job)
    return job.to_h.to_s
  end


  def pretty_print_tube(tube)
    return tube.to_h.to_s
  end


  def tube_matches?(tube, opts = {})
    return matcher(MATCHABLE_TUBE_ATTRIBUTES, tube, opts)
  end

  protected

  def climber
    return @climber ||= StalkClimber::Climber.new(BeanCounter.beanstalkd_url, test_tube)
  end


  def matcher(valid_attributes, matchable_object, opts = {})
    # Refresh state/stats before checking match
    return false unless matchable_object.exists?
    return (opts.keys & valid_attributes).all? do |key|
      opts[key] === matchable_object.send(stats_method_name(key))
    end
  end


  def test_tube
    return @test_tube ||= TEST_TUBE
  end


  def stats_method_name(stats_attr)
    return STATS_METHOD_NAMES[stats_attr.to_sym]
  end

end
