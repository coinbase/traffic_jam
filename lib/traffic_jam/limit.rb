require_relative 'scripts'

module TrafficJam
  # This class represents a rate limit on an action, value pair. For example, if
  # rate limiting the number of requests per IP address, the action could be
  # +:requests+ and the value would be the IP address. The class exposes atomic
  # increment operations and allows querying of the current amount used and
  # amount remaining.
  class Limit
    # @!attribute [r] action
    #   @return [Symbol] the name of the action being rate limited.
    # @!attribute [r] value
    #   @return [String] the target of the limit. The value should be a string
    #     or convertible to a distinct string when +to_s+ is called. If you
    #     would like to use objects that can be converted to a unique string,
    #     like a database-mapped object with an ID, you can implement
    #     +to_rate_limit_value+ on the object, which returns a deterministic
    #     string unique to that object.
    # @!attribute [r] max
    #   @return [Integer] the integral cap of the limit amount.
    # @!attribute [r] period
    #   @return [Integer] the duration of the limit in seconds. Regardless of
    #     the current amount used, after the period passes, the amount used will
    #     be 0.
    attr_reader :action, :max, :period, :value

    # Constructor takes an action name as a symbol, a maximum cap, and the
    # period of limit. +max+ and +period+ are required keyword arguments.
    #
    # @param action [Symbol] action name
    # @param value [String] limit target value
    # @param max [Integer] required limit maximum
    # @param period [Integer] required limit period in seconds
    # @raise [ArgumentError] if max or period is nil
    def initialize(action, value, max: nil, period: nil)
      raise ArgumentError.new('Max is required') if max.nil?
      raise ArgumentError.new('Period is required') if period.nil?
      @action, @value, @max, @period = action, value, max, period
    end

    # Return whether incrementing by the given amount would exceed limit. Does
    # not change amount used.
    #
    # @param amount [Integer]
    # @return [Boolean]
    def exceeded?(amount = 1)
      used + amount > max
    end

    # Return itself if incrementing by the given amount would exceed limit,
    # otherwise nil. Does not change amount used.
    #
    # @return [TrafficJam::Limit, nil]
    def limit_exceeded(amount = 1)
      self if exceeded?(amount)
    end

    # Increment the amount used by the given number. Does not perform increment
    # if the operation would exceed the limit. Returns whether the operation was
    # successful. Time of increment can be specified optionally with a keyword
    # argument, which is useful for rolling back with a decrement.
    #
    # @param amount [Integer] amount to increment by
    # @param time [Time] time when increment occurs
    # @return [Boolean] true if increment succeded and false if incrementing
    #   would exceed the limit
    def increment(amount = 1, time: Time.now)
      return amount <= 0 if max.zero?

      if amount != amount.to_i
        raise ArgumentError.new("Amount must be an integer")
      end

      timestamp = (time.to_f * 1000).round
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

    # Increment the amount used by the given number. Does not perform increment
    # if the operation would exceed the limit. Raises an exception if the
    # operation is unsuccessful. Time of# increment can be specified optionally
    # with a keyword argument, which is useful for rolling back with a
    # decrement.
    #
    # @param amount [Integer] amount to increment by
    # @param time [Time] time when increment occurs
    # @return [nil]
    # @raise [TrafficJam::LimitExceededError] if incrementing would exceed the
    #   limit
    def increment!(amount = 1, time: Time.now)
      if !increment(amount, time: time)
        if logger.present?
          logger.info(
            message: "Exceeded Limit - Action: #{action}, Value: #{value}, Max: #{max}, Limit: #{limit}",
            action: action,
            value: value,
            max: max,
            limit: limit
          )
        end
        raise TrafficJam::LimitExceededError.new(self)
      end
    end

    # Decrement the amount used by the given number. Time of decrement can be
    # specified optionally with a keyword argument, which is useful for rolling
    # back an increment operation at a certain time.
    #
    # @param amount [Integer] amount to increment by
    # @param time [Time] time when increment occurs
    # @return [true]
    def decrement(amount = 1, time: Time.now)
      increment(-amount, time: time)
    end

    # Reset amount used to 0.
    #
    # @return [nil]
    def reset
      redis.del(key)
      nil
    end

    # Return amount of limit used, taking time drift into account.
    #
    # @return [Integer] amount used
    def used
      return 0 if max.zero?

      obj = redis.hgetall(key)
      timestamp = obj['timestamp']
      amount = obj['amount']
      if timestamp && amount
        time_passed = Time.now.to_f - timestamp.to_i / 1000.0
        drift = max * time_passed / period
        last_amount = [amount.to_f, max].min
        [(last_amount - drift).ceil, 0].max
      else
        0
      end
    end

    # Return amount of limit remaining, taking time drift into account.
    #
    # @return [Integer] amount remaining
    def remaining
      max - used
    end

    def flatten
      [self]
    end

    private
    def config
      TrafficJam.config
    end

    def redis
      config.redis
    end

    def logger
      config.logger
    end

    def key
      if @key.nil?
        converted_value =
          begin
            value.to_rate_limit_value
          rescue NoMethodError
            value
          end
        hash = Digest::MD5.base64digest(converted_value.to_s)
        hash = hash[0...config.hash_length]
        @key = "#{config.key_prefix}:#{action}:#{hash}"
      end
      @key
    end
  end
end
