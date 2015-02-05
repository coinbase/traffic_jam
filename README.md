# RateLimit

This is a library for enforcing time based rate limits. This can be used to cap the number of actions that may be performed by one actor. Alternatively, this can be used to enforce any integral cap on an amount that can be incremented/decremented by arbitrary integer amounts. A limit consists of an action name, a maximum amount, and a period of time in seconds.

Instead of guaranteeing that the number of actions will never exceed the cap the given timeframe, the approach we take is to use a continuously regenerating limit. The amount remaining will constantly increase at a rate of *max / period* until it hits the cap. If, for example, the limit is 60 per minute, a user could increment by 60 at once, then increment by 1 per second forever without hitting the cap. As a consequence, *this algorithm guarantees that the total amount incremented will be less than twice the limit in any given timeframe*.

## Usage

```
require 'rate-limit'

limit = RateLimit.new(:requests_per_user, 3, 1)
limit.increment("user1")      # => true
limit.increment("user1", 2)   # => true
limit.increment("user1")      # => false

sleep 1

limit.increment("user1", 2)   # => true
limit.exceeded?("user1", 1)   # => false
limit.exceeded?("user1", 2)   # => true

limit.used("user1")  # => 2
limit.used("user1")  # => 1
```

*For all methods, `value` must be a string or convertible to a distinct string when `to_s` is called.*

### Constructor

`RateLimit.new(*action name*, *cap*, *period in seconds*)`

### increment(value, amount = 1)

Increment the amount used by the given number. Returns true if increment succeded and false if incrementing would exceed the limit.

### decrement(value, amount = 1)

Decrement the amount used by the given number. Will never decrement below 0. Always returns true.

### increment!(value, amount = 1)

Increment the amount used by the given number. Raises `RateLimit::ExceededError` if incrementing would exceed the limit.

### exceeded?(value, amount = 1)

Return whether incrementing by the given amount would exceed limit. Does not change amount used.

### reset(value)

Sets amount used to 0.

### used(value)

Return current amount used.

### remaining(value)

Return current amount remaining.

### reset_all

Reset all limits. *Warning: Not to be used in production.*

## Registering limits

Fixed limits can be registered for a key if the cap does not change depending on the value. All instance methods are available on the class.

```
RateLimit.register(:requests_per_user, 3, 1)

limit = RateLimit.find(:requests_per_user)
limit.increment("user1", 2)  # => true

RateLimit.increment(:requests_per_user, "user1", 1)  # => true
RateLimit.used(:requests_per_user, "user1")          # => 3
```

## Changing limit cap for a value

Given an instance of `RateLimit` with a maximum cap and a period, the behavior is to increase the amount remaining at a rate of *max / period* since the last time `increment` was called for the given value. If the cap is defined on a per-value basis, it is good practice to call `increment(value, 0)` if the limit changes.

For example:

```
user.requests_per_hour = 10

limit = RateLimit.new(:requests_per_user, user.requests_per_hour, 60 * 60)
limit.increment(user.id, 8)  # => true

sleep 60

limit.increment(value, 0)

user.requests_per_hour = 20
limit = RateLimit.new(:requests_per_user, user.requests_per_hour, 60 * 60)
limit.increment(user.id, 8)  # => true
```

## Running tests

The `REDIS_URI` environment variable can be set in tests, and defaults to `redis://localhost:6379`.

```
rake test
```

To run a performance/stress test, see the `test/stress.rb` script.
