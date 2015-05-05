module TrafficJam
  # A limit group is a way of enforcing a cap over a set of limits with the
  # guarantee that either all limits will be incremented or none. This is useful
  # if you must check multiple limits before allowing an action to be taken.
  # Limit groups can contain other limit groups.
  class LimitGroup
    attr_reader :limits

    # Creates a limit group from a collection of limits or other limit groups.
    #
    # @param limits [Array<TrafficJam::Limit>] either an array or splat of
    #   limits or other limit groups
    # @param ignore_nil_values [Boolean] silently drop limits with a nil value
    def initialize(*limits, ignore_nil_values: false)
      @limits = limits.flatten
      @ignore_nil_values = ignore_nil_values
      if @ignore_nil_values
        @limits.reject! do |limit|
          limit.respond_to?(:value) && limit.value.nil?
        end
      end
    end

    # Add a limit to the group.
    #
    # @param limit [TrafficJam::Limit, TrafficJam::LimitGroup]
    def <<(limit)
      if !(@ignore_nil_values && limit.value.nil?)
        limits << limit
      end
    end

    # Attempt to increment the limits by the given amount. Does not increment
    # if incrementing would exceed any limit.
    #
    # @param amount [Integer] amount to increment by
    # @param time [Time] optional time of increment
    # @return [Boolean] whether increment operation was successful
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

    # Increment the limits by the given amount. Raises an error and does not
    # increment if doing so would exceed any limit.
    #
    # @param amount [Integer] amount to increment by
    # @param time [Time] optional time of increment
    # @return [nil]
    # @raise [TrafficJam::LimitExceededError] if increment would exceed any
    #   limits
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
      end
    end

    # Decrement the limits by the given amount.
    #
    # @param amount [Integer] amount to decrement by
    # @param time [Time] optional time of decrement
    # @return [true]
    def decrement(amount = 1, time: Time.now)
      limits.all? { |limit| limit.decrement(amount, time: time) }
    end

    # Return whether incrementing by the given amount would exceed any limit.
    # Does not change amount used.
    #
    # @param amount [Integer]
    # @return [Boolean] whether any limit would be exceeded
    def exceeded?(amount = 1)
      limits.any? { |limit| limit.exceeded?(amount) }
    end

    # Return the first limit to be exceeded if incrementing by the given amount,
    # or nil otherwise. Does not change amount used for any limit.
    #
    # @param amount [Integer]
    # @return [TrafficJam::Limit, nil]
    def limit_exceeded(amount = 1)
      limits.each do |limit|
        limit_exceeded = limit.limit_exceeded(amount)
        return limit_exceeded if limit_exceeded
      end
      nil
    end

    # Resets all limits to 0.
    def reset
      limits.each(&:reset)
      nil
    end

    # Return minimum amount remaining of any limit.
    #
    # @return [Integer] amount remaining in limit group
    def remaining
      limits.map(&:remaining).min
    end

    # Return flattened list of limit. Will return list limits even if this group
    # contains nested limit groups.
    #
    # @return [Array<TrafficJam::Limit>] list of limits
    def flatten
      limits.map(&:flatten).flatten
    end
  end
end
