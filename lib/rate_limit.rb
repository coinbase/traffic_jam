require 'ostruct'
require 'digest/md5'
require_relative 'rate_limit/errors'
require_relative 'rate_limit/scripts'


class RateLimit
  include Errors
  include Scripts

  @@config = OpenStruct.new(
    key_prefix: 'rate_limit',
  )

  attr_reader :name, :max, :period

  def initialize(name, max, period)
    @name, @max, @period = name, max, period
  end

  def reset_all
    redis.keys("#{key_prefix}:*").each { |key| redis.del(key) }
  end

  def exceeded?(value, amount = 1)
    used(value) + amount > max
  end

  def increment(value, amount = 1)
    return amount > 0 if max.zero?

    if amount != amount.to_i
      raise ArgumentError.new("Amount must be an integer")
    end

    timestamp = (Time.now.to_f * 1000).round
    argv = [timestamp, amount.to_i, max, period * 1000]

    result =
      begin
        redis.evalsha(
          INCREMENT_SCRIPT_HASH, keys: [key(value)], argv: argv)
      rescue Redis::CommandError => e
        redis.eval(INCREMENT_SCRIPT, keys: [key(value)], argv: argv)
      end

    !!result
  end

  def increment!(value, amount = 1)
    if !increment(value, amount)
      raise RateLimit::ExceededError.new(self)
    end
  end

  def decrement(value, amount = 1)
    return true if max.zero?
    increment(value, -amount)
  end

  def reset(value)
    redis.del(key(value))
  end

  def used(value)
    return 0 if max.zero?

    obj = redis.hgetall(key(value))
    timestamp = obj['timestamp']
    amount = obj['amount']
    if timestamp && amount
      time_passed = Time.now.to_f - timestamp.to_i / 1000.0
      drift = max * time_passed / period
      [(amount.to_f - drift).ceil, 0].max
    else
      0
    end
  end

  def remaining(value)
    max - used(value)
  end

  private
  def redis
    @@config.redis
  end

  def key(value)
    hash = Digest::MD5.base64digest(value.to_s)
    hash = hash[0...@@config.hash_length] if @@config.hash_length
    "#{@@config.key_prefix}:#{name}:#{hash}"
  end

  class << self
    def config
      @@config
    end

    def register(name, max, period)
      @limits ||= {}
      @limits[name.to_sym] = new(name, max, period)
    end

    def find(name)
      @limits ||= {}
      @limits[name.to_sym]
    end

    %w( exceeded? increment increment! decrement reset used remaining )
      .each do |method|
      define_method(method) do |limit, *args|
        rate_limit = find(limit)
        raise RateLimit::LimitNotFound.new(limit) if rate_limit.nil?
        rate_limit.send(method, *args)
      end
    end
  end
end
