require 'forwardable'

class BeanCounter::Strategy::GemeraldBeanstalkStrategy::Job

  extend Forwardable

  def_delegators :@gemerald_job, :body, :stats

  attr_reader :connection

  # Attributes that should be retrieved via the gemerald job's stats. This
  # list is used to dynamically create the appropriate accessor methods
  STATS_METHODS = %w[
    age buries delay id kicks pri releases reserves
    state time-left timeouts ttr tube
  ]

  # Simple accessors allowing direct access to job stats attributes
  STATS_METHODS.each do |stat_method|
    define_method stat_method.gsub(/-/, '_') do
      return @gemerald_job.stats[stat_method]
    end
  end


  # Attempts to delete the job. Returns true if deletion succeeds or if job
  # does not exist. Returns false if job could not be deleted (typically due
  # to it being reserved by another connection).
  #
  # @return [Boolean] If the given job was successfully deleted or does not
  #   exist, returns true. Otherwise returns false.
  def delete
    response = connection.transmit("delete #{id}")
    if response == "DELETED\r\n" || !exists?
      return true
    else
      return false
    end
  end


  # Returns a Boolean indicating whether or not the job still exists.
  # @return [Boolean] If job state is deleted or the job does not exist
  #   on the beanstalk server, returns false. If job state is not deleted,
  #   returns true if the job exists on the beanstalk server.
  def exists?
    return false if state == 'deleted'
    return connection.transmit("stats-job #{id}") != "NOT_FOUND\r\n"
  end


  # Initialize a new GemeraldBeanstalkStrategy::Job wrapping the provided
  # `gemerald_job` in the context of the provided `connection`.
  def initialize(gemerald_job, connection)
    @gemerald_job = gemerald_job
    @connection = connection
  end


  # Augment job stats to provide a Hash representation of the job.
  # @return [Hash] Hash representation of the job
  def to_hash
    stats_pairs = stats.to_a
    stats_pairs << ['body', body]
    stats_pairs << ['connection', connection]

    hash = Hash[stats_pairs.sort_by!(&:first)]
    hash.delete('file')

    return hash
  end

end
