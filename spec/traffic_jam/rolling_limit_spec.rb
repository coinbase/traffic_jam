require_relative '../spec_helper'

describe TrafficJam::RollingLimit do
  include RedisHelper

  TrafficJam.configure do |config|
    config.redis = RedisHelper.redis
  end

  let(:max) { 3 }
  let(:limit) do
    TrafficJam::RollingLimit.new(:test, 'user1', max: max, period: period)
  end

  after do
    Spy.teardown
  end

  describe :increment do
    let(:period) { 60 * 60 }

    it 'should raise an argument error if given a float' do
      assert_raises(ArgumentError) do
        limit.increment(1.5)
      end
    end

    describe 'when max is zero' do
      let(:max) { 0 }
      it 'should be false for any amount' do
        assert !limit.increment
      end
    end
  end

  describe 'one time' do
    let(:period) { 0 }

    describe :increment do
      it 'should be true when rate limit is not exceeded' do
        assert limit.increment(1)
      end

      it 'should be false when raise limit is exceeded' do
        assert limit.increment(3)
        assert limit.increment(3)
        assert !limit.increment(4)
      end

      it 'should never call eval' do
        eval_spy = Spy.on(RedisHelper.redis, :eval).and_call_through
        limit.increment(1)
        assert_equal 0, eval_spy.calls.count
      end
    end

    describe :used do
      it 'should be 0' do
        assert_equal 0, limit.used
        limit.increment(1)
        assert_equal 0, limit.used
      end
    end
  end

  describe 'timeframe' do
    let(:period) { 60 * 60 }

    describe :increment do
      it 'should be true when limit is not exceeded' do
        assert limit.increment(1)
      end

      it 'should be false when limit is exceeded' do
        assert limit.increment(1)
        assert limit.increment(2)
        assert !limit.increment(1)
      end

      it 'should be a no-op when limit would be exceeded' do
        assert limit.increment(2)
        assert !limit.increment(2)
        assert limit.increment(1)
      end

      it 'should be true when sufficient time passes' do
        assert limit.increment(3)
        Timecop.travel(period / 2)
        assert !limit.increment(1)
        Timecop.travel(period)
        assert limit.increment(3)
      end

      describe 'when max is zero' do
        let(:max) { 0 }
        it 'should be false for any positive amount' do
          assert !limit.increment
        end
      end

      describe 'when max is changed to a lower amount' do
        it 'should still expire after period' do
          limit = TrafficJam::RollingLimit.new(
            :test, 'user1', max: 4, period: period
          )
          limit.increment!(4)

          limit = TrafficJam::RollingLimit.new(
            :test, 'user1', max: 2, period: period
          )
          assert !limit.increment

          Timecop.travel(period + 1)
          assert_equal 0, limit.used
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
        Timecop.travel(period / 2)
        assert_equal 2, limit.used
      end

      it 'should not exceed maximum when limit changes' do
        limit.increment!(3)
        limit2 = TrafficJam::RollingLimit.new(
          :test, 'user1', max: 2, period: period
        )
        assert_equal 2, limit2.used
      end
    end
  end
end
