require 'gemerald_beanstalk'
require 'gemerald_beanstalk/plugins/introspection'
require 'gemerald_beanstalk/plugins/direct_connection'
require 'forwardable'

class BeanCounter::Strategy::GemeraldBeanstalkStrategy < BeanCounter::Strategy

  # Regex for checking for valid V4 IP addresses
  V4_IP_REGEX = /^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(?::\d+)?$/

  extend Forwardable

  def_delegator :job_enumerator, :each, :jobs
  def_delegator :tube_enumerator, :each, :tubes


  # Collects all jobs enqueued during the execution of the provided `block`.
  # Returns an Array of GemeraldBeanstalkStrategy::Job.
  #
  # Fulfills {BeanCounter::Strategy#collect_new_jobs} contract.
  #
  # @see BeanCounter::Strategy#collect_new_jobs
  # @see BeanCounter::Strategy::GemeraldBeanstalkStrategy::Job
  # @yield Nothing is yielded to the provided `block`
  # @raise [ArgumentError] if a block is not provided.
  # @return [Array<GemeraldBeanstalkStrategy::Job>] all jobs enqueued during the
  #   execution of the provided `block`
  def collect_new_jobs
    raise ArgumentError, 'Block required' unless block_given?

    max_id_pairs = beanstalks.map do |beanstalk|
      [beanstalk, beanstalk.jobs[-1] ? beanstalk.jobs[-1].id : 0]
    end
    max_ids = Hash[max_id_pairs]

    yield

    new_jobs = []
    # Jobs are collected in reverse, so iterate beanstalks in reverse too
    beanstalks.reverse.each do |beanstalk|
      jobs = beanstalk.jobs
      index = -1
      while (job = jobs[index]) && job.id > max_ids[beanstalk] do
        new_jobs << strategy_job(job)
        index -= 1
      end
    end
    # Flip new jobs to maintain beanstalk, id asc order
    return new_jobs.reverse
  end


  # Attempts to delete the provided GemeraldBeanstalkStrategy::Job `job`.
  # Returns true if deletion succeeds or if `job` does not exist. Returns false
  # if `job` could not be deleted (typically due to it being reserved by
  # another connection).
  #
  # Fulfills {BeanCounter::Strategy#delete_job} contract.
  #
  # @see BeanCounter::Strategy#delete_job
  # @param job [GemeraldBeanstalkStrategy::Job] the job to be deleted
  # @return [Boolean] If the given job was successfully deleted or does not
  #   exist, returns true. Otherwise returns false.
  def delete_job(job)
    return job.delete
  end


  # Initialize a new GemeraldBeanstalkStrategy. This includes initializing
  # GemeraldBeanstalk::Servers for each of the beanstalk_urls visible to
  # BeanCounter and also spawning direct connections to those servers.
  def initialize
    @clients = {}
    @beanstalk_servers = []
    BeanCounter.beanstalkd_url.each do |url|
      server = GemeraldBeanstalk::Server.new(*parse_url(url))
      @clients[server.beanstalk] = server.beanstalk.direct_connection_client
      @beanstalk_servers << server
    end
  end


  # Returns a Boolean indicating whether or not the provided
  # GemeraldBeanstalkStrategy::Job `job` matches the given Hash of `options`.
  #
  # See {MATCHABLE_JOB_ATTRIBUTES} for a list of
  # attributes that can be used when matching.
  #
  # Fulfills {BeanCounter::Strategy#job_matches?} contract.
  #
  # @see MATCHABLE_JOB_ATTRIBUTES
  # @see BeanCounter::Strategy#job_matches?
  # @param job [GemeraldBeanstalkStrategy::Job] the job to evaluate for a matche.
  # @param options
  #   [Hash{String, Symbol => Numeric, Proc, Range, Regexp, String, Symbol}]
  #   Options to be used to evaluate a match.
  # @return [Boolean] If job exists and matches the provided options, returns
  #   true. Otherwise, returns false.
  def job_matches?(job, options = {})
    return matcher(MATCHABLE_JOB_ATTRIBUTES, job, options)
  end


  # Returns a String representation of the GemeraldBeanstalkStrategy::Job `job`
  # in a pretty, human readable format.
  #
  # Fulfills {BeanCounter::Strategy#pretty_print_job} contract.
  #
  # @see BeanCounter::Strategy#pretty_print_job
  # @param job [GemeraldBeanstalkStrategy::Job] the job to print in a more
  #   readable format.
  # @return [String] A more human-readable representation of `job`.
  def pretty_print_job(job)
    hash = job.to_hash
    hash.delete('connection')
    return hash.to_s
  end


  # Returns a String representation of `tube` in a pretty, human readable format.
  #
  # Fulfills {BeanCounter::Strategy#pretty_print_tube} contract.
  #
  # @see BeanCounter::Strategy#pretty_print_tube
  # @param tube [GemeraldBeanstalkStrategy::Tube] the tube to print in a more
  #   readable format.
  # @return [String] A more human-readable representation of `tube`.
  def pretty_print_tube(tube)
    return tube.to_hash.to_s
  end


  # Returns a boolean indicating whether or not the provided
  # GemeraldBeanstalkStrategy::Tube, `tube`, matches the given Hash of `options`.
  #
  # See {MATCHABLE_TUBE_ATTRIBUTES} for a list of attributes that can be used
  # when evaluating a match.
  #
  # Fulfills {BeanCounter::Strategy#tube_matches?} contract.
  #
  # @see BeanCounter::Strategy#tube_matches?
  # @param tube [GemeraldBeanstalkStrategy::Tube] the tube to evaluate a match
  #   against.
  # @param options
  #   [Hash{String, Symbol => Numeric, Proc, Range, Regexp, String, Symbol}]
  #   a Hash of options to use when evaluating a match.
  # @return [Boolean] If `tube` exists and matches against the provided options,
  #   returns true. Otherwise returns false.
  def tube_matches?(tube, options = {})
    return false if tube.nil?
    return matcher(MATCHABLE_TUBE_ATTRIBUTES, tube, options)
  end

  private

  # The collection of GemeraldBeanstalk servers the strategy built during
  # initialization
  attr_reader :beanstalk_servers


  # The collection of beanstalks belonginging to the GemeraldBeanstalk servers
  # that were created during initialization.
  #
  # @return [Array<GemeraldBeanstalk::Beanstalk>] the Beanstalks of the
  #   GemeraldBeanstalk::Servers
  def beanstalks
    return @beanstalks ||= @beanstalk_servers.map(&:beanstalk)
  end


  # Returns an enumerator that enumerates all jobs on all beanstalk servers in
  # the order the beanstalk servers are defined in ascending order. Jobs are
  # returned as GemeraldBeanstalkStrategy::Job.
  def job_enumerator
    return Enumerator.new do |yielder|
      beanstalks.each do |beanstalk|
        beanstalk.jobs.each do |job|
          yielder << strategy_job(job)
        end
      end
    end
  end


  # Generic match evaluator that compares the Hash of `options` given to the
  # Strategy representation of the given `matchable`.
  def matcher(valid_attributes, matchable, options = {})
    return false unless matchable.exists?
    return (options.keys & valid_attributes).all? do |key|
      options[key] === matchable.send(key.to_s.gsub(/-/, '_'))
    end
  end


  # Parses a variety of forms of beanstalk URL and returns a pair including the
  # hostname and possibly a port given by the url.
  def parse_url(url)
    unless V4_IP_REGEX === url
      uri = URI.parse(url)
      if uri.scheme && uri.host
        raise(ArgumentError, "Invalid beanstalk URI: #{url}") unless uri.scheme == 'beanstalk'
        host = uri.host
        port = uri.port
      end
    end
    unless host
      match = url.split(/:/)
      host = match[0]
      port = match[1]
    end
    return port ? [host, Integer(port)] : [host]
  end


  # Helper method to transform a GemeraldBeanstalk::Job into a
  # BeanCounter::Strategy::GemeraldBeanstalkStrategy::Job. The strategy
  # specific job class is intended to hide native job implementation interface
  # specifics and prevent meddling with native Job internals.
  def strategy_job(gemerald_job)
    return BeanCounter::Strategy::GemeraldBeanstalkStrategy::Job.new(gemerald_job, @clients[gemerald_job.beanstalk])
  end


  # Helper method to transform a `tube_name` into a
  # BeanCounter::Strategy::GemeraldBeanstalkStrategy::Tube. The strategy
  # specific tube class is intended to hide native tube implementation interface
  # specifics and prevent meddling with native Tube internals. Also handles
  # merging of tube data from multiple servers, as such, requires access to
  # beanstalk servers.
  def strategy_tube(tube_name)
    return BeanCounter::Strategy::GemeraldBeanstalkStrategy::Tube.new(tube_name, beanstalks)
  end


  # Returns an enumerator that enumerates all tubes on all beanstalk servers.
  # Each tube is included in the enumeration only once, regardless of how many
  # servers contain an instance of that tube. Tube stats are merged before they
  # are yielded by the enumerator as a GemeraldBeanstalkdStrategy::Tube.
  def tube_enumerator
    tubes_in_pool = beanstalks.inject([]) do |memo, beanstalk|
      memo.concat(beanstalk.tubes.keys)
    end
    tubes_in_pool.uniq!
    return Enumerator.new do |yielder|
      tubes_in_pool.each do |tube_name|
        yielder << strategy_tube(tube_name)
      end
    end
  end

end
