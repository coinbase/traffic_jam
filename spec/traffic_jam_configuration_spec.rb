require_relative 'spec_helper'

describe TrafficJam do
  include RedisHelper

  let(:config) { TrafficJam::Configuration.new }

  before { config.register(:test, 3, 60) }

  describe 'constructor' do
    it "should take default options" do
      config = TrafficJam::Configuration.new(key_prefix: 'hello')
      config.key_prefix = 'hello'
    end
  end

  describe '::max' do
    it "should look up the registered max for the action" do
      assert_equal 3, config.max(:test)
    end
  end

  describe '::period' do
    it "should look up the registered max for the action" do
      assert_equal 60, config.period(:test)
    end
  end

  describe '.unregister' do
    it "should remove unregistered actions" do
      config.register(:test_2, 1, 1)
      assert_equal({max: 1, period: 1}, config.limits(:test_2))

      config.unregister(:test_2)
      assert_raises(TrafficJam::LimitNotFound) do
        config.limits(:test_2)
      end
    end
  end
end
