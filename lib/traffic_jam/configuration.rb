module TrafficJam
  class Configuration
    OPTIONS = %i( key_prefix hash_length redis )
    attr_accessor *OPTIONS

    def initialize(options = {})
      OPTIONS.each do |option|
        self.send("#{option}=", options[option])
      end
    end

    def register(action, max, period)
      @limits ||= {}
      @limits[action.to_sym] = { max: max, period: period }
    end

    def max(action)
      limits(action)[:max]
    end

    def period(action)
      limits(action)[:period]
    end

    def limits(action)
      @limits ||= {}
      limits = @limits[action.to_sym]
      raise TrafficJam::LimitNotFound.new(action) if limits.nil?
      limits
    end
  end
end
