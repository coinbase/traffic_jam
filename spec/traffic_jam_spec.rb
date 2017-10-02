require_relative 'spec_helper'

describe TrafficJam do
  include RedisHelper

  TrafficJam.configure do |config|
    config.redis = RedisHelper.redis
    config.register(:test, 3, 60)
    config.register(:test4, 4, 60)
  end

  let(:value) { "user1" }

  describe '::limit' do
    it "should return limit instance with registered limits" do
      limit = TrafficJam.limit(:test, value)
      assert_equal :test, limit.action
      assert_equal value, limit.value
      assert_equal 3, limit.max
      assert_equal 60, limit.period
    end

    it "should raise error if not found" do
      assert_raises(TrafficJam::LimitNotFound) do
        TrafficJam.limit(:test2, value)
      end
    end
  end

  describe '::reset_all' do
    it "should reset all rate limits" do
      limit = TrafficJam.increment!(:test, value)
      limit = TrafficJam.increment!(:test4, value)
      assert_equal 1, TrafficJam.used(:test, value)
      assert_equal 1, TrafficJam.used(:test4, value)

      TrafficJam.reset_all
      assert_equal 0, TrafficJam.used(:test, value)
      assert_equal 0, TrafficJam.used(:test4, value)
    end

    it "should reset all rate limits for one action" do
      limit = TrafficJam.increment!(:test, value)
      limit = TrafficJam.increment!(:test4, value)
      assert_equal 1, TrafficJam.used(:test, value)
      assert_equal 1, TrafficJam.used(:test4, value)

      TrafficJam.reset_all(action: :test)
      assert_equal 0, TrafficJam.used(:test, value)
      assert_equal 1, TrafficJam.used(:test4, value)
    end
  end

  describe 'class helpers' do
    before { TrafficJam.config.register(:test, 3, 60) }
    let(:value) { "user1" }

    it "should call methods with registered limits" do
      TrafficJam.increment(:test, value, 1)
      assert_equal 1, TrafficJam.used(:test, value)
    end

    it "should raise error if limit not found" do
      assert_raises(TrafficJam::LimitNotFound) do
        TrafficJam.increment(:test2, value, 1)
      end
    end
  end
end
