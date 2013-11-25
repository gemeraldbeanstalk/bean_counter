module BeanCounter::MiniTest

  def assert_enqueued(opts = {})
    enqueue_assertion(strategy, opts)
  end


  def assert_enqueues(opts = {})
    raise ArgumentError, 'Block required' unless block_given?

    found = strategy.collect_new { yield }
    enqueue_assertion(found, opts)
  end


  def refute_enqueued(opts = {})
    enqueue_refutation(strategy, opts)
  end


  def refute_enqueues(opts = {})
    raise ArgumentError, 'Block required' unless block_given?

    found = strategy.collect_new { yield }
    enqueue_refutation(found, opts)
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
    refute(found, [
      "Assertion failed: Expected no jobs found matching #{opts.to_s},",
      "found #{strategy.pretty_print_job(found)}",
    ].join(' '))
  end


  def strategy
    return BeanCounter.strategy
  end


  def reset!(tube_name = nil)
    strategy.each do |job|
      strategy.delete_job(job) if tube_name.nil? || strategy.job_matches?(job, :tube => tube_name)
    end
  end

end
