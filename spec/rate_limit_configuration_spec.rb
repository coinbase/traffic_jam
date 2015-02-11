require 'rate-limit'
require_relative 'spec_helper'


describe RateLimit do
  include RedisHelper

  let(:config) { RateLimit::Configuration.new }

  before { config.register(:test, 3, 60) }


  describe 'constructor' do
    it "should take default options" do
      config = RateLimit::Configuration.new(key_prefix: 'hello')
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
end
