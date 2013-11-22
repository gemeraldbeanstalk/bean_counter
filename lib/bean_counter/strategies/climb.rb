require 'stalk_climber'

class BeanCounter::Strategy::Climb < BeanCounter::Strategy

  extend Forwardable

  TEST_TUBE = 'bean_counter_stalk_climber_test'

  attr_writer :test_tube

  def_delegators :climber, :each


  protected

  def climber
    return @climber ||= StalkClimber::Climber.new(BeanCounter.beanstalkd_url, test_tube)
  end


  def test_tube
    return @test_tube ||= TEST_TUBE
  end

end
