require_relative 'spec_helper'

describe TrafficJam do
  include RedisHelper

  let(:config) { TrafficJam::Configuration.new }

  before { config.register(:test, 3, 60) }

  describe 'constructor' do
    it "should take default options" do
      config = TrafficJam::Configuration.new(key_prefix: 'hello')
      assert_equal 'hello', config.key_prefix
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
end
