require_relative 'scripts'

module TrafficJam
  # This class represents a rolling limit on an action, value pair. For example,
  # if limiting the amount of money a user can transfer in a week, the action
  # could be +:transfers+ and the value would be the user ID. The class exposes
  # atomic increment operations and allows querying of the current amount used
  # and amount remaining.
  #
  # This class also handles 0 for period, where 0 is no period (each
  # request is compared to the max).
  #
  # This class departs from the design of Limit by tracking a sum of the actions
  # in a second, in a hash keyed by the timestamp. Therefore, this limit can put
  # a lot of data size pressure on the Redis storage, so use it wisely.
  class RollingLimit < Limit
    # Constructor takes an action name as a symbol, a maximum cap, and the
    # period of limit. +max+ and +period+ are required keyword arguments.
    #
    # @param action [Symbol] action name
    # @param value [String] limit target value
    # @param max [Integer] required limit maximum
    # @param period [Integer] required limit period in seconds
    # @raise [ArgumentError] if max or period is nil
    def initialize(action, value, max: nil, period: nil)
      super(action, value, max: max, period: period)
    end

    # Increment the amount used by the given number. Rolls back the increment
    # if the operation exceeds the limit. Returns whether the operation was
    # successful. Time of increment can be specified optionally with a keyword
    # argument, which is not really useful since it be undone by used.
    #
    # @param amount [Integer] amount to increment by
    # @param time [Time] time when increment occurs (ignored)
    # @return [Boolean] true if increment succeded and false if incrementing
    #   would exceed the limit
    def increment(amount = 1, time: Time.now)
      raise ArgumentError, 'Amount must be an integer' if amount != amount.to_i
      return amount <= 0 if max.zero?
      return amount <= max if period.zero?
      return true if amount.zero?
      return false if amount > max

      !run_incr([time.to_i, amount.to_i, max, period]).nil?
    end

    # Return amount of limit used
    #
    # @return [Integer] amount used
    def used
      return 0 if max.zero? || period.zero?
      [sum, max].min
    end

    private

    def sum
      run_sum([Time.now.to_i, period])
    end

    def clear_before
      Time.now.to_i - period
    end

    def run_sum(argv)
      redis.evalsha(Scripts::SUM_ROLLING_HASH, keys: [key], argv: argv)
    rescue Redis::CommandError => error
      raise error if /ERR Error running script/ =~ error.message
      redis.eval(Scripts::SUM_ROLLING, keys: [key], argv: argv)
    end

    def run_incr(argv)
      redis.evalsha(
        Scripts::INCREMENT_ROLLING_HASH, keys: [key], argv: argv
      )
    rescue Redis::CommandError => error
      raise error if /ERR Error running script/ =~ error.message
      redis.eval(Scripts::INCREMENT_ROLLING, keys: [key], argv: argv)
    end
  end
end
