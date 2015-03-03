module TrafficJam
  class LimitGroup
    attr_reader :limits

    def initialize(*limits)
      @limits = limits.flatten
    end

    def <<(limit)
      @limits << limit
    end

    def increment(amount = 1)
      time = Time.now
      exceeded_index = @limits.find_index do |limit|
        !limit.increment(amount, time: time)
      end

      if exceeded_index.nil?
        nil
      else
        @limits[0...exceeded_index].each do |limit|
          limit.decrement(amount, time: time)
        end
        @limits[exceeded_index]
      end
    end

    def increment!(amount = 1)
      limit = increment(amount)
      if !limit.nil?
        raise TrafficJam::LimitExceededError.new(limit)
      end
    end

    def decrement(amount = 1)
      @limits.all? { |limit| limit.decrement(amount) }
    end

    def exceeded?(amount = 1)
      @limits.find { |limit| limit.exceeded?(amount) }
    end

    def reset
      @limits.each(&:reset)
      nil
    end

    def remaining
      @limits.map(&:remaining).min
    end
  end
end
