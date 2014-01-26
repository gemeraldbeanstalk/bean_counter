class BeanCounter::Strategy::GemeraldBeanstalkStrategy::Tube

  # The name of the tube represented by the object
  attr_reader :name

  # Attributes that should be obtained via the tube's stats. This list is used
  # to dynamically create the attribute accessor methods.
  STATS_METHODS = %w[
    cmd-delete cmd-pause-tube current-jobs-buried current-jobs-delayed
    current-jobs-ready current-jobs-reserved current-jobs-urgent current-using
    current-waiting current-watching pause pause-time-left total-jobs
  ]

  STATS_METHODS.each do |attr_method|
    define_method attr_method.gsub(/-/, '_') do
      return to_hash[attr_method]
    end
  end

  # Returns a Boolean indicating whether or not the tube exists in the pool.
  # @return [Boolean] Returns true if tube exists on any of the servers in the
  #   pool, otherwise returns false.
  def exists?
    tubes_in_pool = @beanstalks.inject([]) do |memo, beanstalk|
      memo.concat(beanstalk.tubes.keys)
    end
    tubes_in_pool.uniq!
    return tubes_in_pool.include?(@name)
  end


  # Initialize a new GemeraldBeanstalkStrategy::Tube representing all tubes
  # named `tube_name` in the given pool of `beanstalks`.
  def initialize(tube_name, beanstalks)
    @name = tube_name
    @beanstalks = beanstalks
  end


  # Retrieves stats for the given `tube_name` from all known servers and merges
  # numeric stats. Matches Beaneater's treatment of a tube as a collective
  # entity and not a per-server entity.
  def to_hash
    return @beanstalks.inject({}) do |hash, beanstalk|
      next hash if (tube = beanstalk.tubes[name]).nil?
      next tube.stats if hash.empty?

      tube.stats.each do |stat, value|
        next unless value.is_a?(Numeric)
        hash[stat] += value
      end
      hash
    end
  end

end
