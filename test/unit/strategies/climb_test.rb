require 'test_helper'

class ClimbTest < BeanCounter::TestCase

  setup do
    @strategy = BeanCounter::Strategy::Climb.new
  end

  context 'Enumerable' do

    should 'honor Enumberable contract' do
      assert @strategy.respond_to?(:each)
      begin
        @strategy.each do
          break
        end
      rescue NotImplementedError
        raise "Expected subclass of Strategy, BeanCounter::Strategy::Climb,  to provide #each"
      end
    end


    context 'select_with_limit' do

      should 'avoid unnecessary element traversal' do
        client_id = client.object_id
        job_ids = (1..3).map do |index|
          message = (index.even? ? client_id : client_id - rand(100)).to_s
          client.transmit("put 0 0 120 #{message.bytesize}\r\n#{message}")[:id]
        end
        client_id = client_id.to_s
        found = false
        selected = @strategy.select_with_limit(1) do |element|
          if element.body == client_id
            found = true
            true
          else
            raise 'Unnecessary element traversal. Should have exited loop already' if found
          end
        end
        job = selected.first
        assert_equal client_id, job.body
        job_ids.each do |id|
          client.transmit("delete #{id}")
        end
      end

    end



  end


  context '#test_tube' do

    should 'return default test tube unless set otherwise' do
      assert_equal BeanCounter::Strategy::Climb::TEST_TUBE, @strategy.send(:test_tube)
      @strategy.test_tube = new_tube = 'bean_counter_stalk_climber_test_new'
      assert_equal new_tube, @strategy.send(:test_tube)
      @strategy.test_tube = nil
      assert_equal BeanCounter::Strategy::Climb::TEST_TUBE, @strategy.send(:test_tube)
    end

  end

end
