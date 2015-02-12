module RateLimit
  class TargetGroup
    def initialize(targets)
      @targets = targets
    end

    def increment(amount = 1)
      time = Time.now
      exceeded_index = @targets.find_index do |target|
        !target.increment(amount, time: time)
      end

      if exceeded_index.nil?
        nil
      else
        @targets[0...exceeded_index].each do |target|
          target.decrement(amount, time: time)
        end
        @targets[exceeded_index]
      end
    end

    def increment!(amount = 1)
      target = increment(amount)
      if !target.nil?
        raise RateLimit::ExceededError.new(target)
      end
    end

    def decrement(amount = 1)
      @targets.all? { |target| target.decrement(amount) }
    end

    def exceeded?(amount = 1)
      @targets.find { |target| target.exceeded?(amount) }
    end

    def reset
      @targets.each(&:reset)
      nil
    end

    def remaining
      @targets.map(&:remaining).min
    end
  end
end
