module BeanCounter::SpecMatchers

  def have_enqueued(expected)
    BeanCounter::EnqueuedExpectation.new(expected)
  end

  def have_tube(expected)
    BeanCounter::TubeExpectation.new(expected)
  end

end
