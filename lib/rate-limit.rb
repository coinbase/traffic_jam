require 'ostruct'
require 'digest/md5'
require_relative 'rate-limit/errors'
require_relative 'rate-limit/configuration'
require_relative 'rate-limit/target'
require_relative 'rate-limit/target-group'


module RateLimit
  include Errors

  @config = Configuration.new(
    key_prefix: 'rate_limit'
  )

  class << self
    attr_reader :config

    def configure
      yield config
    end

    def target(action, value)
      limits = config.limits(action.to_sym)
      RateLimit::Target.new(action, value, **limits)
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
