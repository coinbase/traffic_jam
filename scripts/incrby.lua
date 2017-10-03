local arg_amount = tonumber(ARGV[1])
local arg_max = tonumber(ARGV[2])

local old_amount = tonumber(redis.call("GET", KEYS[1]))
local new_amount

if not old_amount then
  new_amount = arg_amount
else
  new_amount = old_amount + arg_amount

  if new_amount > arg_max then
    return false
  end
end

redis.call("INCRBY", KEYS[1], arg_amount)
return true