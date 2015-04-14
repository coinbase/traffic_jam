module TrafficJam
  class LimitGroup
    attr_reader :limits

    def initialize(*limits, ignore_nil_values: false)
      @limits = limits.flatten
      @ignore_nil_values = ignore_nil_values
      if @ignore_nil_values
        @limits.reject! do |limit|
          limit.respond_to?(:value) && limit.value.nil?
        end
      end
    end

    def <<(limit)
      if !(@ignore_nil_values && limit.value.nil?)
        limits << limit
      end
    end

    def increment(amount = 1, time: Time.now)
      exceeded_index = limits.find_index do |limit|
        !limit.increment(amount, time: time)
      end
      if exceeded_index
        limits[0...exceeded_index].each do |limit|
          limit.decrement(amount, time: time)
        end
      end
      exceeded_index.nil?
    end

    def increment!(amount = 1, time: Time.now)
      exception = nil
      exceeded_index = limits.find_index do |limit|
        begin
          limit.increment!(amount, time: time)
        rescue TrafficJam::LimitExceededError => e
          exception = e
          true
        end
      end
      if exceeded_index
        limits[0...exceeded_index].each do |limit|
          limit.decrement(amount, time: time)
        end
        raise exception
      elsif block_given?
        result =
          begin
            yield
          rescue => e
            decrement(amount, time: time)
            raise e
          end
        decrement(amount, time: time) if result == false
        result
      end
    end

    def decrement(amount = 1, time: Time.now)
      limits.all? { |limit| limit.decrement(amount, time: time) }
    end

    def exceeded?(amount = 1)
      limits.any? { |limit| limit.exceeded?(amount) }
    end

    def limit_exceeded(amount = 1)
      limits.each do |limit|
        limit_exceeded = limit.limit_exceeded(amount)
        return limit_exceeded if limit_exceeded
      end
      nil
    end

    def reset
      limits.each(&:reset)
      nil
    end

    def remaining
      limits.map(&:remaining).min
    end

    def flatten
      limits.map(&:flatten).flatten
    end
  end
end
