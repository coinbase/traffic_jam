require 'ostruct'
require 'digest/md5'
require_relative 'traffic_jam/errors'
require_relative 'traffic_jam/configuration'
require_relative 'traffic_jam/limit'
require_relative 'traffic_jam/limit_group'


module TrafficJam
  include Errors

  @config = Configuration.new(
    key_prefix: 'traffic_jam',
    hash_length: 22
  )

  class << self
    attr_reader :config

    def configure
      yield config
    end

    def target(action, value)
      limits = config.limits(action.to_sym)
      TrafficJam::Limit.new(action, value, **limits)
    end

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
    end

    %w( exceeded? increment increment! decrement reset used remaining )
      .each do |method|
      define_method(method) do |action, value, *args|
        target(action, value).send(method, *args)
      end
    end
  end
end
