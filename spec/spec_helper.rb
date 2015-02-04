require 'redis'
require 'timecop'
require 'minitest/autorun'
require 'spy/integration'


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
