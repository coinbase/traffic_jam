local arg_timestamp = tonumber(ARGV[1])
local arg_amount = tonumber(ARGV[2])
local arg_max = tonumber(ARGV[3])
local arg_period = tonumber(ARGV[4])

local old_timestamp = redis.call("HGET", KEYS[1], "timestamp")

local new_amount
local new_timestamp

if not old_timestamp
then
   new_amount = arg_amount
   new_timestamp = arg_timestamp
else
   local time_diff = arg_timestamp - tonumber(old_timestamp)
   local drift_amount = time_diff * arg_max / arg_period
   if time_diff < 0
   then
      local incr_amount
      local incr_magnitude
      if arg_amount < 0
      then
        incr_amount = arg_amount - drift_amount
        incr_magnitude = -incr_amount
      else
        incr_amount = arg_amount + drift_amount
        incr_magnitude = incr_amount
      end
      if incr_magnitude <= 0
      then
         return true
      end
      local old_amount = tonumber(redis.call("HGET", KEYS[1], "amount"))
      old_amount = math.min(old_amount, arg_max)
      new_amount = old_amount + incr_amount
      new_timestamp = old_timestamp
   else
      local old_amount = tonumber(redis.call("HGET", KEYS[1], "amount"))
      old_amount = math.min(old_amount, arg_max)
      local current_amount = math.max(old_amount - drift_amount, 0)
      new_amount = current_amount + arg_amount
      new_timestamp = arg_timestamp
   end
end

if new_amount > arg_max
then
   return false
end

redis.call("HSET", KEYS[1], "amount", new_amount)
redis.call("HSET", KEYS[1], "timestamp", new_timestamp)
redis.call("EXPIRE", KEYS[1], arg_period)
return true
