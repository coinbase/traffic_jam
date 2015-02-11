class RateLimit
  module Errors
    class LimitNotFound < StandardError; end

    class ExceededError < StandardError
      attr_accessor :rate_limit

      def initialize(rate_limit)
        super("Rate limit exceeded: #{rate_limit.action}")
        @rate_limit = rate_limit
      end
    end
  end
end
