require 'stalk_climber'

class BeanCounter::Strategy::StalkClimberStrategy < BeanCounter::Strategy

  extend Forwardable

  TEST_TUBE = 'bean_counter_stalk_climber_test'

  attr_writer :test_tube

  def_delegators :climber, :each


  def collect_new
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
  end


  def job_matches?(job, opts = {})
    # Refresh job state/stats before checking match
    return false unless job.exists?
    return (opts.keys & MATCHABLE_ATTRIBUTES).all? {|key| opts[key] === job.send(key) }
  end


  def pretty_print_job(job)
    return job.to_h.to_s
  end

  protected

  def climber
    return @climber ||= StalkClimber::Climber.new(BeanCounter.beanstalkd_url, test_tube)
  end


  def test_tube
    return @test_tube ||= TEST_TUBE
  end

end
