# degradable

Automatically degrade a feature when failure rate reaches a certain threshold. This is useful for the following if a new feature causes error rates to spike:

- Toggling off feature flags
- Disabling a service entirely
- Notifying the team when any of these has happened

_Note: this is not a replacement for a monitoring/alerting solution, but can augment your alerts by automatically disabling the functionality that is firing them off._

## Installation

1. Add the dependency to your `shard.yml`:

   ```yaml
   dependencies:
     degradable:
       github: jgaskins/degradable
   ```

2. Run `shards install`

## Usage

Degradable comes out of the box with two adapters, one for operating in application memory and one for coordinating across multiple instances of the application via Redis.

In the following example, we're using [`Pennant` for feature flags](https://github.com/jgaskins/pennant) and Slack for notifications. When the failure rate reaches 20% (and a minimum number of total checks to avoid wild swings with a low sample size), we will notify our team via the `#degradations` Slack channel and automatically disable the feature flag.

### In-memory adapter

This adapter is for features that can be disabled based on failures within a single process

```crystal
require "degradable"
require "slack"
require "pennant"

# Degrade MY_FEATURE when failure rate reaches 20%
MY_FEATURE = Degradable::Memory.new(failure_threshold: 0.2) do
  Slack.notify "#degradations", "Feature MY_FEATURE has reached 20% failure rate"
  Pennant.disable "my_feature"
end
```

### Redis adapter

This adapter allows you to coordinate degradation of a feature across all instances of your entire application, as long as they can all talk to the same Redis instance. The only difference in how you use it is that you need to pass in a Redis instance to use as well as the name of the feature (which will be stored in Redis).

```crystal
require "degradable"
require "slack"
require "pennant"
require "redis"

redis = Redis::Client.from_env("REDIS_URL")

# Degrade MY_FEATURE when failure rate reaches 20%
MY_FEATURE = Degradable::Redis.new("my-feature", failure_threshold: 0.2, redis: redis) do
  Slack.notify "#degradations", "Feature MY_FEATURE has reached 20% failure rate"
  Pennant.disable "my_feature"
end
```

### Running feature checks

Now that we have our feature's failure handler defined, we can invoke a check by calling `MY_FEATURE.check` with a block:

```crystal
if Pennant.enabled? "my_feature"
  MY_FEATURE.check { feature_flag_enabled_behavior }
else
  feature_flag_disabled_behavior
end
```

## Contributing

1. Fork it (<https://github.com/jgaskins/degradable/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Jamie Gaskins](https://github.com/jgaskins) - creator and maintainer
