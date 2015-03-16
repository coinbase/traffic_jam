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

  describe :constructor do
    it "should accept an array of limits" do
      limit_group = TrafficJam::LimitGroup.new([limit1, limit2])
      assert_equal 2, limit_group.limits.size
    end

    it "should accept a splat of limits" do
      limit_group = TrafficJam::LimitGroup.new(limit1, limit2)
      assert_equal 2, limit_group.limits.size
    end

    it "should accept no arguments" do
      limit_group = TrafficJam::LimitGroup.new
      assert_equal 0, limit_group.limits.size
    end
  end

  describe :increment do
    it "should be true when no limits are exceeded" do
      assert limit_group.increment(2)
    end

    it "should false when any limit is exceeded" do
      assert !limit_group.increment(3)
    end

    it "should be increment all limits when none are exceeded" do
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
    it "should increment all limits when none are exceeded" do
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

    describe "when passed a block" do
      it "should return result of block" do
        called = false
        block = ->{ called = true; :result }
        assert_equal :result, limit_group.increment!(2, &block)
        assert called
      end

      it "should not execute block when any limit is exceeded" do
        called = false
        assert_raises(TrafficJam::LimitExceededError) do
          limit_group.increment!(3) { called = true }
        end
        assert !called
      end

      it "should not increment limits if block raises an exception" do
        assert_raises(StandardError) do
          limit_group.increment!(2) { raise StandardError.new }
        end
        assert_equal 0, limit1.used
        assert_equal 0, limit2.used
      end

      it "should not increment limits if block evaluates to false" do
        limit_group.increment!(2) { false }
        assert_equal 0, limit1.used
        assert_equal 0, limit2.used
      end

      it "should increment limits if block evaluates to nil" do
        limit_group.increment!(2) { nil }
        assert_equal 2, limit1.used
        assert_equal 2, limit2.used
      end
    end

    describe "when group contains other groups" do
      let(:meta_group) { TrafficJam::LimitGroup.new(limit_group) }

      it "should raise error with limit instance" do
        exception = assert_raises(TrafficJam::LimitExceededError) do
          meta_group.increment!(3)
        end
        assert_equal limit2, exception.limit
      end
    end
  end

  describe :exceeded? do
    it "should be true when an limit would be exceeded" do
      limit_group.increment(2)
      assert limit_group.exceeded?(1)
    end

    it "should be false when amount would not exceed any limit" do
      limit_group.increment(1)
      assert !limit_group.exceeded?(1)
    end
  end

  describe :limit_exceeded do
    it "should be the limit that would exceed limit" do
      limit_group.increment(2)
      assert_equal limit2, limit_group.limit_exceeded(1)
    end

    it "should be nil when amount would not exceed limit" do
      limit_group.increment(1)
      assert_nil limit_group.limit_exceeded(1)
    end
  end

  describe :remaining do
    it "should be the minimum amount remaining of all limits" do
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

  describe :<< do
    it "should add limit to the group" do
      limit_group = TrafficJam::LimitGroup.new([limit1])
      assert_equal 1, limit_group.limits.size
      limit_group << limit2
      assert_equal 2, limit_group.limits.size
    end
  end

  describe :flatten do
    let(:meta_group) { TrafficJam::LimitGroup.new(limit_group) }

    it "should be a flattened list of limits" do
      assert_equal [limit1, limit2], meta_group.flatten
    end
  end
end
