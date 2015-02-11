require 'rate-limit'
require_relative 'spec_helper'


describe RateLimit do
  include RedisHelper

  RateLimit.configure do |config|
    config.redis = RedisHelper.redis
    config.register(:test, 3, 60)
    config.register(:test4, 4, 60)
  end

  let(:value) { "user1" }

  describe '::target' do
    it "should return target instance with registered limits" do
      rate_limit = RateLimit.target(:test, value)
      assert_equal :test, rate_limit.action
      assert_equal value, rate_limit.value
      assert_equal 3, rate_limit.max
      assert_equal 60, rate_limit.period
    end

    it "should raise error if not found" do
      assert_raises(RateLimit::LimitNotFound) do
        RateLimit.target(:test2, value)
      end
    end
  end

  describe '::reset_all' do
    it "should reset all rate limits" do
      rate_limit = RateLimit.increment!(:test, value)
      rate_limit = RateLimit.increment!(:test4, value)
      assert_equal 1, RateLimit.used(:test, value)
      assert_equal 1, RateLimit.used(:test4, value)

      RateLimit.reset_all
      assert_equal 0, RateLimit.used(:test, value)
      assert_equal 0, RateLimit.used(:test4, value)
    end

    it "should reset all rate limits for one action" do
      rate_limit = RateLimit.increment!(:test, value)
      rate_limit = RateLimit.increment!(:test4, value)
      assert_equal 1, RateLimit.used(:test, value)
      assert_equal 1, RateLimit.used(:test4, value)

      RateLimit.reset_all(action: :test)
      assert_equal 0, RateLimit.used(:test, value)
      assert_equal 1, RateLimit.used(:test4, value)
    end
  end

  describe 'class helpers' do
    before { RateLimit.config.register(:test, 3, 60) }
    let(:value) { "user1" }

    it "should call methods with registered limits" do
      RateLimit.increment(:test, value, 1)
      assert_equal 1, RateLimit.used(:test, value)
    end

    it "should raise error if limit not found" do
      assert_raises(RateLimit::LimitNotFound) do
        RateLimit.increment(:test2, value, 1)
      end
    end
  end
end
