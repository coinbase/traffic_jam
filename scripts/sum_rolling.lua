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
local arg_period = tonumber(ARGV[2])
local sum = 0

local clear_before = arg_timestamp - arg_period
local mytable = hgetall(KEYS[1])
if mytable ~= false then
  for key, val in pairs(mytable) do
    if tonumber(key) < clear_before then
      redis.call('HDEL', KEYS[1], key)
    else
      sum = sum + tonumber(val)
    end
  end
end

return sum