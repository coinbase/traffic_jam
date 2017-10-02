-- gets all fields from a hash as a dictionary
local hgetall = function (key)
  local bulk = redis.call('HGETALL', key)
	local result = {}
	local nextkey
	for i, v in ipairs(bulk) do
		if i % 2 == 1 then
			nextkey = v
		else
			result[nextkey] = v
		end
	end
	return result
end

local arg_timestamp = tonumber(ARGV[1])
local arg_amount = tonumber(ARGV[2])
local arg_max = tonumber(ARGV[3])
local arg_period = tonumber(ARGV[4])

local sum = arg_amount

local clear_before = arg_timestamp - arg_period
local mytable = hgetall(KEYS[1])
if mytable ~= false then
  -- print key -> value for mytable
  print('mytable:')
  for key, val in pairs(mytable) do
    print('    ' .. key .. ' -> ' .. val)
    if tonumber(key) < clear_before then
      redis.call('HDEL', KEYS[1], key)
    else
      sum = sum + tonumber(val)
    end
  end
end

if sum > arg_max then
  return false
end

redis.call("HINCRBY", KEYS[1], arg_timestamp, arg_amount)
redis.call("EXPIRE", KEYS[1], arg_period)
return true
