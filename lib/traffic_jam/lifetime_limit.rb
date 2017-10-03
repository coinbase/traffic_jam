module TrafficJam
  # This class represents a lifetime limit on an action, value pair. For example, if
  # limiting the amount of money a user can transfer, the action could be
  # +:transfers+ and the value would be the user ID. The class exposes atomic
  # increment operations and allows querying of the current amount used and
  # amount remaining.
  class LifetimeLimit < Limit
    # Constructor takes an action name as a symbol, a maximum cap, and the
    # period of limit. +max+ and +period+ are required keyword arguments.
    #
    # @param action [Symbol] action name
    # @param value [String] limit target value
    # @param max [Integer] required limit maximum
    # @raise [ArgumentError] if max is nil
    def initialize(action, value, max: nil)
      super(action, value, max: max, period: -1)
    end

    # Increment the amount used by the given number. Does not perform increment
    # if the operation would exceed the limit. Returns whether the operation was
    # successful.
    #
    # @param amount [Integer] amount to increment by
    # @return [Boolean] true if increment succeded and false if incrementing
    #   would exceed the limit
    def increment(amount = 1, time: Time.now)
      raise ArgumentError, 'Amount must be an integer' if amount != amount.to_i
      return amount <= 0 if max.zero?

      !!run_script([amount.to_i, max])
    end

    # Return amount of limit used
    #
    # @return [Integer] amount used
    def used
      return 0 if max.zero?
      amount = redis.get(key) || 0
      [amount.to_i, max].min
    end

    private

    def run_script(argv)
      redis.evalsha(
        Scripts::INCRBY_HASH, keys: [key], argv: argv
      )
    rescue Redis::CommandError => error
      raise error if /ERR Error running script/ =~ error.message
      redis.eval(Scripts::INCRBY, keys: [key], argv: argv)
    end
  end
end
