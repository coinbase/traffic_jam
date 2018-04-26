require_relative 'limit'
require_relative 'scripts'

module TrafficJam
  # GCRA (Genetic Cell Rate Algorithm) is a leaky bucket type rate limiting
  # algorithm. GCRA works by tracking remaining limit through a time called
  # the “theoretical arrival time” (TAT), which is seeded on the first request
  # by adding a duration representing its cost to the current time. The cost
  # is calculated as a multiplier of our “emission interval” (T), which is
  # derived from the rate at which we want the bucket to refill. In this
  # implementation, the emission interval is derived from the period,
  # assuming that the user wants the limit to completely replenish over the
  # period. When any subsequent request comes in, we take the existing TAT,
  # subtract a fixed buffer representing the limit’s total burst capacity from
  # it (τ + T), and compare the result to the current time. This result represents
  # the next time to allow a request. If it’s in the past, we allow the incoming
  # request, and if it’s in the future, we don’t. After a successful request, a
  # new TAT is calculated by adding T. (see https://brandur.org/rate-limiting)
  #
  class GCRALimit < Limit
    # Increment the amount used by the given number. Does not perform increment
    # if the operation would exceed the limit. Returns whether the operation was
    # successful.
    #
    # @param amount [Integer] amount to increment by
    # @param time [Time] time is ignored
    # @return [Boolean] true if increment succeeded and false if incrementing
    #   would exceed the limit
    def increment(amount = 1, time: Time.now)
      return true if amount == 0
      return false if max == 0
      raise ArgumentError.new("Amount must be positive") if amount < 0
      raise ArgumentError.new("Amount must be an integer") if amount != amount.to_i
      return false if amount > max
      !!run_increment_script(key, [max, period, amount])
    end

    # Decrement the amount used by the given number.
    #
    # @param amount [Integer] amount to decrement by
    # @param time [Time] time is ignored
    # @raise [NotImplementedError] decrement is not defined for SimpleLimit
    def decrement(_amount = 1, time: Time.now)
      raise NotImplementedError, "decrement is not defined for GRCALimit"
    end

    # Return amount of limit used, taking time drift into account.
    #
    # @return [Integer] amount used
    def used
      return 0 if max.zero?
      run_read_script(key, [max, period])
    end

    def key_prefix
      "#{config.key_prefix}:s"
    end

    private

    def run_increment_script(key, argv)
      redis.evalsha(Scripts::INCREMENT_GCRA_HASH, keys: [key], argv: argv)
    rescue Redis::CommandError
      redis.eval(Scripts::INCREMENT_GCRA, keys: [key], argv: argv)
    end

    def run_read_script(key, argv)
      redis.evalsha(Scripts::READ_GCRA_HASH, keys: [key], argv: argv)
    rescue Redis::CommandError
      redis.eval(Scripts::READ_GCRA, keys: [key], argv: argv)
    end
  end
end
