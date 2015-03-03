require_relative 'spec_helper'

describe TrafficJam do
  include RedisHelper

  TrafficJam.configure do |config|
    config.redis = RedisHelper.redis
  end

  let(:limit1) do
    TrafficJam::Limit.new(:test, "user1", max: 3, period: 60 * 60)
  end
  let(:limit2) do
    TrafficJam::Limit.new(:test, "user2", max: 2, period: 60 * 60)
  end
  let(:limit_group) { TrafficJam::LimitGroup.new([limit1, limit2]) }

  describe :increment do
    it "should be nil when no limit targets are exceeded" do
      assert_nil limit_group.increment(2)
    end

    it "should be the first limit target to be exceeded" do
      assert_equal limit2, limit_group.increment(3)
    end

    it "should be increment all limit targets when none are exceeded" do
      limit_group.increment(2)
      assert_equal 2, limit1.used
      assert_equal 2, limit2.used
    end

    it "should be a no-op when limit would be exceeded" do
      limit_group.increment(3)
      assert_equal 0, limit1.used
      assert_equal 0, limit2.used
    end
  end

  describe :increment! do
    it "should be increment all limit targets when none are exceeded" do
      limit_group.increment!(2)
      assert_equal 2, limit1.used
      assert_equal 2, limit2.used
    end

    it "should be a no-op when limit would be exceeded" do
      assert_raises(TrafficJam::LimitExceededError) do
        limit_group.increment!(3)
      end
      assert_equal 0, limit1.used
      assert_equal 0, limit2.used
    end
  end

  describe :exceeded? do
    it "should be the limit that would exceed limit" do
      limit_group.increment(2)
      assert_equal limit2, limit_group.exceeded?(1)
    end

    it "should be nil when amount would not exceed limit" do
      limit_group.increment(1)
      assert_nil limit_group.exceeded?(1)
    end
  end

  describe :remaining do
    it "should be the minimum amount remaining of all targets" do
      assert_equal 2, limit_group.remaining
      limit1.increment!(2)
      assert_equal 1, limit_group.remaining
    end
  end

  describe :reset do
    it "should reset all limits to 0" do
      limit1.increment(2)
      limit2.increment(1)
      limit_group.reset
      assert_equal 0, limit1.used
      assert_equal 0, limit2.used
    end
  end

  describe :decrement do
    it "should reduce the amount used" do
      limit_group.increment(2)
      limit_group.decrement(1)
      assert_equal 1, limit1.used
      assert_equal 1, limit2.used
    end
  end
end
