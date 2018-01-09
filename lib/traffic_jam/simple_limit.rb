require_relative 'limit'
require_relative 'scripts'

module TrafficJam
  # A SimpleLimit is a limit type that is more efficient for increments but does
  # not support decrements or changing the max value without a complete reset.
  # This means that if the period or max value for an action, value key changes,
  # the used and remaining values cannot be preserved.
  #
  # This works by storing a key in Redis with a millisecond-precision expiry
  # representing the time that the limit will be completely reset. Each
  # increment operation converts the increment amount into the number of
  # milliseconds to be added to the expiry.
  #
  # Example: Limit is 5 per 10 seconds.
  #     An increment by 1 first sets the key to expire in 2s.
  #     Another immediate increment by 4 sets the expiry to 10s.
  #     Subsequent increments fail until clock time catches up to expiry
  class SimpleLimit < Limit
    # Increment the amount used by the given number. Does not perform increment
    # if the operation would exceed the limit. Returns whether the operation was
    # successful.
    #
    # @param amount [Integer] amount to increment by
    # @param time [Time] time is ignored
    # @return [Boolean] true if increment succeded and false if incrementing
    #   would exceed the limit
    def increment(amount = 1, time: Time.now)
      return true if amount == 0
      return false if max == 0
      raise ArgumentError.new("Amount must be positive") if amount < 0

      if amount != amount.to_i
        raise ArgumentError.new("Amount must be an integer")
      end

      return false if amount > max

      incrby = (period * 1000 * amount / max).to_i
      argv = [incrby, period * 1000]

      result =
        begin
          redis.evalsha(
            Scripts::INCREMENT_SIMPLE_HASH, keys: [key], argv: argv)
        rescue Redis::CommandError
          redis.eval(Scripts::INCREMENT_SIMPLE, keys: [key], argv: argv)
        end

      case result
      when 0
        return true
      when -1
        raise Errors::InvalidKeyError, "Redis key #{key} has no expire time set"
      when -2
        return false
      else
        raise Errors::UnknownReturnValue,
              "Received unexpected return value #{result} from " \
              "increment_simple eval"
      end
    end

    # Decrement the amount used by the given number.
    #
    # @param amount [Integer] amount to decrement by
    # @param time [Time] time is ignored
    # @raise [NotImplementedError] decrement is not defined for SimpleLimit
    def decrement(_amount = 1, time: Time.now)
      raise NotImplementedError, "decrement is not defined for SimpleLimit"
    end

    # Return amount of limit used, taking time drift into account.
    #
    # @return [Integer] amount used
    def used
      return 0 if max.zero?

      expiry = redis.pttl(key)
      case expiry
      when -1  # key exists but has no associated expire
        raise Errors::InvalidKeyError, "Redis key #{key} has no expire time set"
      when -2  # key does not exist
        return 0
      end

      (max * expiry / (period * 1000.0)).ceil
    end

    def key_prefix
      "#{config.key_prefix}:s"
    end
  end
end
