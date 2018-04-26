-- this script has side-effects, so it requires replicate commands mode
redis.replicate_commands()

local burst = ARGV[1]
local period = ARGV[2]
local cost = ARGV[3]

local increment = period * cost
local burst_offset = period * burst
local now = redis.call("TIME")

-- redis returns time as an array containing two integers: seconds of the epoch
-- time (10 digits) and microseconds (6 digits). for convenience we need to
-- convert them to a floating point number. the resulting number is 16 digits,
-- bordering on the limits of a 64-bit double-precision floating point number.
-- adjust the epoch to be relative to Jan 1, 2017 00:00:00 GMT to avoid floating
-- point problems. this approach is good until "now" is 2,483,228,799 (Wed, 09
-- Sep 2048 01:46:39 GMT), when the adjusted value is 16 digits.
local jan_1_2017 = 1483228800
now = (now[1] - jan_1_2017) + (now[2] / 1000000)

local tat = redis.call("GET", KEYS[1])

if not tat then
  tat = now
else
  tat = tonumber(tat)
end

local new_tat = math.max(tat, now) + increment
local allow_at = new_tat - burst_offset
local diff = now - allow_at

local remaining = math.floor(diff / period + 0.5) -- poor man's round

if remaining < 0 then
  return false
end

local reset_after = new_tat - now
redis.call("SET", KEYS[1], new_tat, "EX", math.ceil(reset_after))
return true
