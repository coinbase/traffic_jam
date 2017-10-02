require_relative '../spec_helper'

describe TrafficJam::RollingLimit do
  include RedisHelper

  TrafficJam.configure do |config|
    config.redis = RedisHelper.redis
  end

  let(:max) { 3 }
  let(:limit) do
    TrafficJam::LifetimeLimit.new(:test, 'user1', max: max)
  end

  after do
    Spy.teardown
  end

  describe :increment do
    it 'should be true when rate limit is not exceeded' do
      assert limit.increment(1)
    end

    it 'should be false when raise limit is exceeded' do
      assert limit.increment(1)
      assert limit.increment(2)
      assert !limit.increment(1)
    end

    it 'should be a no-op when limit would be exceeded' do
      limit.increment(2)
      assert !limit.increment(2)
      assert limit.increment(1)
    end

    it 'should be false when any time passes' do
      assert limit.increment(3)
      Timecop.travel(4000)
      assert !limit.increment(1)
    end

    it 'should only call eval once' do
      eval_spy = Spy.on(RedisHelper.redis, :eval).and_call_through
      limit.increment(1)
      limit.increment(1)
      limit.increment(1)
      assert_equal 1, eval_spy.calls.count
    end

    describe 'when max is changed to a lower amount' do
      it 'should never expire' do
        limit = TrafficJam::LifetimeLimit.new(:test, 'user1', max: 4)
        limit.increment!(4)

        limit = TrafficJam::LifetimeLimit.new(:test, 'user1', max: 2)
        assert !limit.increment(0)
        assert_equal 2, limit.used
      end
    end
  end

  describe :used do
    it 'should be 0 when there has been no incrementing' do
      assert_equal 0, limit.used
    end

    it 'should be the amount used' do
      limit.increment(1)
      assert_equal 1, limit.used
    end

    it 'should not decrease over time' do
      limit.increment(2)
      Timecop.travel(60 / 2)
      assert_equal 2, limit.used
    end

    it 'should not exceed maximum when limit changes' do
      limit.increment!(3)
      limit2 = TrafficJam::LifetimeLimit.new(:test, 'user1', max: 2)
      assert_equal 2, limit2.used
    end
  end
end
