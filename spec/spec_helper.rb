require 'redis'
require 'timecop'
require 'simplecov'
require 'minitest/autorun'
require 'spy/integration'

SimpleCov.start :test_frameworks

if ENV['CI']
  require 'coveralls'
  Coveralls.wear!
end

require 'traffic_jam'

module RedisHelper
  @@redis = Redis.new(url: ENV['REDIS_URI'] || 'redis://localhost:6379')

  def setup
    super
    @@redis.flushdb
    @@redis.script(:flush)
  end

  def self.redis
    @@redis
  end
end
