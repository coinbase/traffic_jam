local arg_incrby = tonumber(ARGV[1])
local arg_max = tonumber(ARGV[2])

local old_value = redis.call("PTTL", KEYS[1])
if old_value == -1 then -- key exists but has no associated expire
   return -1 -- -1 signals key exists but has no associated expire
elseif old_value == -2 then -- key does not exist
   redis.call("SET", KEYS[1], "", "PX", arg_incrby)
else
   local new_value = old_value + arg_incrby
   if new_value > arg_max then
      return -2 -- -2 signals increment exceeds max
   end
   redis.call("PEXPIRE", KEYS[1], new_value)
end

return 0 -- 0 signals success
