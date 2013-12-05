require 'stalk_climber'

class BeanCounter::Strategy::StalkClimberStrategy < BeanCounter::Strategy

  extend Forwardable

  # Index of what method should be called to retrieve each stat
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

  # Default tube used by StalkClimber when probing the beanstalkd pool
  TEST_TUBE = 'bean_counter_stalk_climber_test'

  # The tube that will be used by StalkClimber when probing the beanstalkd pool.
  # Uses TEST_TUBE if no value provided.
  attr_writer :test_tube

  def_delegators :climber, :jobs, :tubes


  # :call-seq:
  #   collect_new_jobs { block } => Array[StalkClimber::Job]
  #
  # Collects all jobs enqueued during the execution of the provided +block+.
  # Returns an Array of StalkClimber::Job.
  #
  # Fulfills Strategy#collect_new_jobs contract. See Strategy#collect_new_jobs
  # for more information.
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


  # :call-seq:
  #   delete_job(job) => Boolean
  #
  # Attempts to delete the given StalkClimber::Job +job+. Returns true if
  # deletion succeeds or if +job+ does not exist. Returns false if +job+ could
  # not be deleted (typically due to it being reserved by another connection).
  #
  # Fulfills Strategy#delete_job contract. See Strategy#delete_job for more
  # information.
  def delete_job(job)
    job.delete
    return true
  rescue Beaneater::NotFoundError
    return job.exists? ? false : true
  end


  # :call-seq:
  #   job_matches?(job, options => {Symbol,String => Numeric,Proc,Range,Regexp,String}) => Boolean
  #
  # Returns a boolean indicating whether or not the provided StalkClimber::Job
  # +job+ matches the given Hash of +options.
  #
  # Fulfills Strategy#job_matches? contract. See Strategy#job_matches? for more
  # information.
  def job_matches?(job, opts = {})
    return matcher(MATCHABLE_JOB_ATTRIBUTES, job, opts)
  end


  # :call-seq:
  #   pretty_print_job(job) => String
  #
  # Returns a String representation of the StalkClimber::Job +job+ in a pretty,
  # human readable format.
  #
  # Fulfills Strategy#pretty_print_job contract. See Strategy#pretty_print_job
  # for more information.
  def pretty_print_job(job)
    return job.to_h.to_s
  end


  # :call-seq:
  #   pretty_print_tube(tube) => String
  #
  # Returns a String representation of +tube+ in a pretty, human readable format.
  #
  # Fulfills Strategy#pretty_print_tube contract. See Strategy#pretty_print_tube
  # for more information.
  def pretty_print_tube(tube)
    return tube.to_h.to_s
  end


  # :call-seq:
  #   tube_matches?(tube, options => {Symbol,String => Numeric,Proc,Range,Regexp,String}) => Boolean
  #
  # Returns a boolean indicating whether or not the provided StalkClimber +tube+
  # matches the given Hash of +options.
  #
  # Fulfills Strategy#tube_matches? contract. See Strategy#tube_matches? for
  # more information.
  def tube_matches?(tube, opts = {})
    return matcher(MATCHABLE_TUBE_ATTRIBUTES, tube, opts)
  end

  private

  # StalkClimber instance used to climb/crawl beanstalkd pool
  def climber
    return @climber ||= StalkClimber::Climber.new(BeanCounter.beanstalkd_url, test_tube)
  end


  # Given the set of valid attributes, +valid_attributes+, determines if every
  # _value_ of +opts+ evaluates to true when compared to the attribute of
  # +matchable+ identified by the corresponding +opts+ _key_.
  def matcher(valid_attributes, matchable, opts = {})
    # Refresh state/stats before checking match
    return false unless matchable.exists?
    return (opts.keys & valid_attributes).all? do |key|
      opts[key] === matchable.send(stats_method_name(key))
    end
  end


  # Simplify lookup of what method to call to retrieve requested stat
  def stats_method_name(stats_attr)
    return STATS_METHOD_NAMES[stats_attr.to_sym]
  end


  # Accessor for test_tube that defaults to TEST_TUBE
  def test_tube
    return @test_tube ||= TEST_TUBE
  end

end
