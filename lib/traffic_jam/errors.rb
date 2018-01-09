module TrafficJam
  module Errors
    class LimitNotFound < StandardError; end

    class LimitExceededError < StandardError
      attr_accessor :limit

      def initialize(limit)
        super("Rate limit exceeded: #{limit.action}")
        @limit = limit
      end
    end

    class InvalidKeyError < StandardError; end
    class UnknownReturnValue < StandardError; end
  end
end
