require 'ostruct'
require 'digest/md5'
require_relative 'traffic_jam/configuration'
require_relative 'traffic_jam/errors'
require_relative 'traffic_jam/gcra_limit'
require_relative 'traffic_jam/lifetime_limit'
require_relative 'traffic_jam/limit'
require_relative 'traffic_jam/limit_group'
require_relative 'traffic_jam/rolling_limit'

module TrafficJam
  include Errors

  @config = Configuration.new(
    key_prefix: 'traffic_jam',
    hash_length: 22
  )

  class << self
    attr_reader :config

    # Configure library in a block.
    #
    # @yield [TrafficJam::Configuration]
    def configure
      yield config
    end

    # Create limit with registed max/period.
    #
    # @param action [Symbol] registered action name
    # @param value [String] limit target value
    # @return [TrafficJam::Limit]
    def limit(action, value)
      limits = config.limits(action.to_sym)
      TrafficJam::Limit.new(action, value, **limits)
    end

    # Reset all limits associated with the given action. If action is omitted or
    # nil, this will reset all limits.
    #
    # @note Not recommended for use in production.
    # @param action [Symbol] action to reset limits for
    # @return [nil]
    def reset_all(action: nil)
      prefix =
        if action.nil?
          "#{config.key_prefix}:*"
        else
          "#{config.key_prefix}:#{action}:*"
        end
      config.redis.keys(prefix).each do |key|
        config.redis.del(key)
      end
      nil
    end

    %w( exceeded? increment increment! decrement reset used remaining )
      .each do |method|
      define_method(method) do |action, value, *args|
        limit(action, value).send(method, *args)
      end
    end
  end
end
