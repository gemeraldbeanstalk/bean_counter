require 'stalk_climber'

class BeanCounter::Strategy::Climb < BeanCounter::Strategy

  TEST_TUBE = 'bean_counter_stalk_climber_test'

  attr_writer :test_tube


  def delete_matched(opts = {})
    climber.each do |job|
     job.delete if job_matches?(job, opts)
    end
  end


  def enqueued?(opts = {})
    return climber.detect { |job| job_matches?(job, opts) }
  end


  def enqueues?(opts = {}, &block)
    min_ids = climber.max_job_ids
    yield
    max_ids = climber.max_job_ids
    found = false
    min_ids.each do |connection, min_id|
      testable_ids = (min_id..max_ids[connection]).to_a
      found = connection.fetch_jobs(testable_ids).compact.detect { |job| job_matches?(job, opts) }
      return found if found
    end
  end


  def reset!(tube_name = nil)
    climber.each do |job|
      next unless tube_name.nil? || job.tube == tube_name
      job.delete
    end
  end

  protected

  def climber
    return @climber ||= StalkClimber::Climber.new(BeanCounter.beanstalkd_url, test_tube)
  end


  def job_matches?(job, opts)
    return opts.all? {|key, value| job.send(key) == value }
  end


  def test_tube
    return @test_tube || TEST_TUBE
  end

end
