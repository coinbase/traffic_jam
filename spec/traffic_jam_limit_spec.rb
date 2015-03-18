require_relative 'spec_helper'

describe TrafficJam do
  include RedisHelper

  TrafficJam.configure do |config|
    config.redis = RedisHelper.redis
  end

  let(:period) { 60 * 60 }
  let(:limit) do
    TrafficJam::Limit.new(:test, "user1", max: 3, period: 60 * 60)
  end

  describe :increment do
    it "should be true when rate limit is not exceeded" do
      assert limit.increment(1)
    end

    it "should be false when raise limit is exceeded" do
      assert limit.increment(1)
      assert limit.increment(2)
      assert !limit.increment(1)
    end

    it "should raise an argument error if given a float" do
      assert_raises(ArgumentError) do
        limit.increment(1.5)
      end
    end

    it "should be a no-op when limit would be exceeded" do
      limit.increment(2)
      assert !limit.increment(2)
      assert limit.increment(1)
    end

    it "should be true when sufficient time passes" do
      assert limit.increment(3)
      Timecop.travel(period / 2)
      assert limit.increment(1)
      Timecop.travel(period)
      assert limit.increment(3)
    end

    it "should only call eval once" do
      eval_spy = Spy.on(RedisHelper.redis, :eval).and_call_through
      limit.increment(1)
      limit.increment(1)
      limit.increment(1)
      assert_equal 1, eval_spy.calls.count
    end

    describe "when max is zero" do
      let(:limit) do
        TrafficJam::Limit.new(:test, "user1", max: 0, period: 60 * 60)
      end

      it "should be false for any positive amount" do
        assert !limit.increment
      end
    end

    describe "when max is changed to a lower amount" do
      it "should still expire after period" do
        limit = TrafficJam::Limit.new(:test, "user1", max: 4, period: 60)
        limit.increment!(4)

        limit = TrafficJam::Limit.new(:test, "user1", max: 2, period: 60)
        limit.increment!(0)

        Timecop.travel(period)
        assert_equal 0, limit.used
      end
    end
  end

  describe :increment! do
    it "should not raise error when rate limit is not exceeded" do
      limit.increment!(1)
    end

    it "should raise error when rate limit is exceeded" do
      limit.increment!(3)
      assert_raises(TrafficJam::LimitExceededError) do
        limit.increment!(1)
      end
    end
  end

  describe :exceeded? do
    it "should be true when amount would exceed limit" do
      limit.increment(2)
      assert limit.exceeded?(2)
    end

    it "should be false when amount would not exceed limit" do
      limit.increment(2)
      assert !limit.exceeded?(1)
    end
  end

  describe :used do
    it "should be 0 when there has been no incrementing" do
      assert_equal 0, limit.used
    end

    it "should be the amount used" do
      limit.increment(1)
      assert_equal 1, limit.used
    end

    it "should decrease over time" do
      limit.increment(2)
      Timecop.travel(period / 2)
      assert_equal 1, limit.used
    end

    it "should not exceed maximum when limit changes" do
      limit.increment!(3)
      limit2 = TrafficJam::Limit.new(:test, "user1", max: 2, period: 60 * 60)
      assert_equal 2, limit2.used
    end
  end

  describe :reset do
    it "should reset current count to 0" do
      limit.increment(3)
      assert_equal 3, limit.used
      limit.reset
      assert_equal 0, limit.used
    end
  end

  describe :decrement do
    it "should reduce the amount used" do
      limit.increment(3)
      limit.decrement(2)
      assert_equal 1, limit.used
    end

    it "should not lower amount used below 0" do
      limit.decrement(2)
      assert !limit.increment(4)
      assert_equal 0, limit.used
    end
  end
end
