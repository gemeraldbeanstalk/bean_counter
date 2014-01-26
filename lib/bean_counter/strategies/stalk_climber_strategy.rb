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

  # Default tube used by StalkClimber when probing the Beanstalkd pool
  TEST_TUBE = 'bean_counter_stalk_climber_test'

  # The tube that will be used by StalkClimber when probing the Beanstalkd pool.
  # Uses {TEST_TUBE} if no value provided.
  attr_writer :test_tube

  def_delegators :climber, :jobs, :tubes


  # Collects all jobs enqueued during the execution of the provided `block`.
  # Returns an Array of StalkClimber::Job.
  #
  # Fulfills {BeanCounter::Strategy#collect_new_jobs} contract.
  #
  # @see BeanCounter::Strategy#collect_new_jobs
  # @yield Nothing is yielded to the provided `block`
  # @raise [ArgumentError] if a block is not provided.
  # @return [Array<StalkClimber::Job>] all jobs enqueued during the execution
  #   of the provided `block`
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


  # Attempts to delete the given StalkClimber::Job `job`. Returns true if
  # deletion succeeds or if `job` does not exist. Returns false if `job` could
  # not be deleted (typically due to it being reserved by another connection).
  #
  # Fulfills {BeanCounter::Strategy#delete_job} contract.
  #
  # @see BeanCounter::Strategy#delete_job
  # @param job [StalkClimber::Job] the job to be deleted
  # @return [Boolean] If the given job was successfully deleted or does not
  #   exist, returns true. Otherwise returns false.
  def delete_job(job)
    job.delete
    return true
  rescue Beaneater::NotFoundError
    return job.exists? ? false : true
  end


  # Returns a Boolean indicating whether or not the provided StalkClimber::Job
  # `job` matches the given Hash of `options`.
  #
  # See {MATCHABLE_JOB_ATTRIBUTES} for a list of
  # attributes that can be used when matching.
  #
  # Fulfills {BeanCounter::Strategy#job_matches?} contract.
  #
  # @see MATCHABLE_JOB_ATTRIBUTES
  # @see BeanCounter::Strategy#job_matches?
  # @param job [StalkClimber::Job] the job to evaluate if matches.
  # @param options
  #   [Hash{String, Symbol => Numeric, Proc, Range, Regexp, String, Symbol}]
  #   Options to be used to evaluate a match.
  # @return [Boolean] If job matches the provided options, returns true.
  #   Otherwise, returns false.
  def job_matches?(job, options = {})
    return matcher(MATCHABLE_JOB_ATTRIBUTES, job, options)
  end


  # Returns a String representation of the StalkClimber::Job `job` in a pretty,
  # human readable format.
  #
  # Fulfills {BeanCounter::Strategy#pretty_print_job} contract.
  #
  # @see BeanCounter::Strategy#pretty_print_job
  # @param job [StalkClimber::Job] the job to print in a more readable format.
  # @return [String] A more human-readable representation of `job`.
  def pretty_print_job(job)
    return job.to_h.to_s
  end


  # Returns a String representation of `tube` in a pretty, human readable format.
  #
  # Fulfills {BeanCounter::Strategy#pretty_print_tube} contract.
  #
  # @see BeanCounter::Strategy#pretty_print_tube
  # @param tube [StalkClimber::Tube] the tube to print in a more readable format.
  # @return [String] A more human-readable representation of `tube`.
  def pretty_print_tube(tube)
    return tube.to_h.to_s
  end


  # Returns a boolean indicating whether or not the provided StalkClimber `tube`
  # matches the given Hash of `options`.
  #
  # See {MATCHABLE_TUBE_ATTRIBUTES} for a list of attributes that can be used
  # when evaluating a match.
  #
  # Fulfills {BeanCounter::Strategy#tube_matches?} contract.
  #
  # @see BeanCounter::Strategy#tube_matches?
  # @param tube [StalkClimber::Tube] the tube to evaluate a match against.
  # @param options
  #   [Hash{String, Symbol => Numeric, Proc, Range, Regexp, String, Symbol}]
  #   a Hash of options to use when evaluating a match.
  # @return [Boolean] If `tube` matches against the provided options, returns
  #   true. Otherwise returns false.
  def tube_matches?(tube, options = {})
    return matcher(MATCHABLE_TUBE_ATTRIBUTES, tube, options)
  end

  private

  # StalkClimber instance used to climb/crawl beanstalkd pool
  # @return [StalkClimber::Climber]
  def climber
    return @climber ||= StalkClimber::Climber.new(BeanCounter.beanstalkd_url, test_tube)
  end


  # Given the set of valid attributes, `valid_attributes`, determines if every
  # `value` of `opts` evaluates to true when compared to the attribute of
  # `matchable` identified by the corresponding `opts` `key`.
  # @return [Boolean]
  def matcher(valid_attributes, matchable, opts = {})
    # Refresh state/stats before checking match
    return false unless matchable.exists?
    return (opts.keys & valid_attributes).all? do |key|
      opts[key] === matchable.send(stats_method_name(key))
    end
  end


  # Simplify lookup of what method to call to retrieve requested stat
  # @return [Symbol]
  def stats_method_name(stats_attr)
    return STATS_METHOD_NAMES[stats_attr.to_sym]
  end


  # Accessor for test_tube that defaults to TEST_TUBE
  def test_tube
    return @test_tube ||= TEST_TUBE
  end

end
