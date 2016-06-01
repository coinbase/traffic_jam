module TrafficJam
  # Configuration for TrafficJam library.
  #
  # @see TrafficJam#configure
  class Configuration
    OPTIONS = %i( key_prefix hash_length redis logger )

    # @!attribute redis
    #   @return [Redis] the connected Redis client the library uses
    # @!attribute key_prefix
    #   @return [String] the prefix of all limit keys in Redis
    # @!attribute hash_length
    #   @return [String] the number of characters to use from the Base64 encoded
    #     hashes of the limit values
    # @!attribute logger
    #   @return [Logger] the logger object to be used for logging that a limit was exceeded
    attr_accessor *OPTIONS

    def initialize(options = {})
      OPTIONS.each do |option|
        self.send("#{option}=", options[option])
      end
    end

    # Register a default cap and period with an action name. For use with
    # {TrafficJam.limit}.
    #
    # @param action [Symbol] action name
    # @param max [Integer] limit cap
    # @param period [Fixnum] limit period in seconds
    def register(action, max, period)
      @limits ||= {}
      @limits[action.to_sym] = { max: max, period: period }
    end

    # Get the limit cap registered to an action.
    #
    # @see #register
    # @return [Integer] limit cap
    def max(action)
      limits(action)[:max]
    end

    # Get the limit period registered to an action.
    #
    # @see #register
    # @return [Integer] limit period in seconds
    def period(action)
      limits(action)[:period]
    end

    # Get registered limit parameters for an action.
    #
    # @see #register
    # @param action [Symbol] action name
    # @return [Hash] max and period parameters in a hash
    # @raise [TrafficJam::LimitNotFound] if action is not registered
    def limits(action)
      @limits ||= {}
      limits = @limits[action.to_sym]
      raise TrafficJam::LimitNotFound.new(action) if limits.nil?
      limits
    end
  end
end
