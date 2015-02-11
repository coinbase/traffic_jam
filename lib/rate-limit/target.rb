require_relative 'scripts'


module RateLimit
  class Target
    attr_reader :action, :max, :period, :value

    def initialize(action, value, max: nil, period: nil)
      raise ArgumentError('Max is required') if max.nil?
      raise ArgumentError('Period is required') if period.nil?
      @action, @value, @max, @period = action, value, max, period
    end

    def exceeded?(amount = 1)
      used + amount > max
    end

    def increment(amount = 1)
      return amount > 0 if max.zero?

      if amount != amount.to_i
        raise ArgumentError.new("Amount must be an integer")
      end

      timestamp = (Time.now.to_f * 1000).round
      argv = [timestamp, amount.to_i, max, period * 1000]

      result =
        begin
          redis.evalsha(
            Scripts::INCREMENT_SCRIPT_HASH, keys: [key], argv: argv)
        rescue Redis::CommandError => e
          redis.eval(Scripts::INCREMENT_SCRIPT, keys: [key], argv: argv)
        end

      !!result
    end

    def increment!(amount = 1)
      if !increment(amount)
        raise RateLimit::ExceededError.new(self)
      end
    end

    def decrement(amount = 1)
      return true if max.zero?
      increment(-amount)
    end

    def reset
      redis.del(key)
    end

    def used
      return 0 if max.zero?

      obj = redis.hgetall(key)
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

    def remaining
      max - used
    end

    private
    def config
      RateLimit.config
    end

    def redis
      config.redis
    end

    def key
      if @key.nil?
        value =
          begin
            value.to_rate_limit_value
          rescue NoMethodError
            value
          end
        hash = Digest::MD5.base64digest(value.to_s)
        hash = hash[0...config.hash_length] if config.hash_length
        @key = "#{config.key_prefix}:#{action}:#{hash}"
      end
      @key
    end
  end
end
