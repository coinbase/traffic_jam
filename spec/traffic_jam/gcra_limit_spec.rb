require_relative '../spec_helper'

describe TrafficJam do
  include RedisHelper

  TrafficJam.configure do |config|
    config.redis = RedisHelper.redis
  end

  let(:period) { 0.1 }
  let(:limit) do
    TrafficJam::GCRALimit.new(:test, "user1", max: 3, period: period)
  end

  describe :increment do
    after { Spy.teardown }

    it "should be true when rate limit is not exceeded" do
      assert limit.increment(1)
    end

    it "should be false when raise limit is exceeded" do
      assert !limit.increment(4)
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
      sleep(period / 2)
      assert limit.increment(1)
      sleep(period * 2)
      assert limit.increment(3)
    end

    describe "when max is zero" do
      let(:limit) do
        TrafficJam::GCRALimit.new(:test, "user1", max: 0, period: period)
      end

      it "should be false for any positive amount" do
        assert !limit.increment
      end
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

    it "should replenish the limit as time passes" do
      limit.increment(4)
      sleep(period / 2.0)
      assert_equal 2, limit.used
    end

    it "should reset after the period elapses" do
      limit.increment(2)
      sleep(period)
      assert_equal 0, limit.used
    end
  end
end
