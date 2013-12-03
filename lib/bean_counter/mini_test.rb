module BeanCounter::MiniTest

  def assert_enqueued(opts = {})
    enqueue_assertion(strategy.jobs, opts)
  end


  def assert_enqueues(opts = {})
    raise ArgumentError, 'Block required' unless block_given?

    found = strategy.collect_new_jobs { yield }
    enqueue_assertion(found, opts)
  end


  def assert_tube(opts = {})
    match = strategy.tubes.any? do |tube|
      strategy.tube_matches?(tube, opts)
    end
    assert match, "Assertion failed: No tubes found matching #{opts.to_s}"
  end


  def refute_enqueued(opts = {})
    enqueue_refutation(strategy.jobs, opts)
  end


  def refute_enqueues(opts = {})
    raise ArgumentError, 'Block required' unless block_given?

    found = strategy.collect_new_jobs { yield }
    enqueue_refutation(found, opts)
  end


  def refute_tube(opts = {})
    match = strategy.tubes.detect do |tube|
      strategy.tube_matches?(tube, opts)
    end
    return assert(true) if match.nil?
    assert(
      false,
      [
        "Assertion failed: Expected no tubes matching #{opts.to_s},",
        "found #{strategy.pretty_print_tube(match)}",
      ].join(' ')
    )
  end

  private


  def enqueue_assertion(collection, opts)
    expected_count = opts[:count]
    found = collection.send(expected_count ? :select : :detect) do |job|
      strategy.job_matches?(job, opts)
    end
    if expected_count
      assert(
        expected_count === found.length,
        [
          "Assertion failed: Expected #{expected_count} jobs matching #{opts.to_s},",
          "found #{found.length}:",
          "#{found.map { |job| strategy.pretty_print_job(job) }.join("\n")}",
        ].join(' ')
     )
    else
      assert !found.nil?, "Assertion failed: No jobs found matching #{opts.to_s}"
    end
  end


  def enqueue_refutation(collection, opts)
    found = collection.detect do |job|
      strategy.job_matches?(job, opts)
    end
    message = [
      "Assertion failed: Expected no jobs found matching #{opts.to_s},",
      "found #{strategy.pretty_print_job(found)}",
    ].join(' ') unless found.nil?
    refute(found, message || '')
  end


  def strategy
    return BeanCounter.strategy
  end

end
