require "./spec_helper"

describe Degradable do
  it "raises the original exception" do
    my_feature = Degradable::Memory.new(0) { }

    exception = nil
    begin
      my_feature.check { raise "hell" }
    rescue ex
      exception = ex
    end

    exception.should_not be_nil
  end

  it "does not invoke the failure handler until the minimum has passed" do
    enabled = true
    my_feature = Degradable::Memory.new(0, minimum: 10) { enabled = false }

    9.times { my_feature.check { raise "hell" } rescue nil }
    enabled.should eq true

    my_feature.check { raise "hell" } rescue nil
    enabled.should eq false
  end

  it "disables a feature after the failure threshold has passed" do
    enabled = true
    my_feature = Degradable::Memory.new(failure_threshold: 0.1, minimum: 100) { enabled = false }

    # No failures for the first 90 checks
    90.times { my_feature.check { } }

    # Failing 10 more times brings the failure rate to 10%
    10.times do
      my_feature.check { raise "hell" }
    rescue
      # Ignore the exception raised in the check
    end

    enabled.should eq false
  end
end

require "redis"
redis = Redis::Client.new
redis.del "degradable:my-feature:checks"
redis.del "degradable:my-feature:failures"

describe Degradable::Redis do
  # This spec simulates two separate instances of a given service using Redis to
  # coordinate feature degradation. Neither instance is required to reach the
  # threshold or minimum on its own, but instead the combined checks and failures
  # between them should still disable the feature and/or fire off a notification.
  it "disables a feature when the combined threshold has been passed" do
    enabled = true
    first = Degradable::Redis.new("my-feature", 0.1, minimum: 100, redis: redis) do
      enabled = false
    end
    second = Degradable::Redis.new("my-feature", 0.1, minimum: 100, redis: redis) do
      enabled = false
    end

    90.times { first.check {} }
    9.times { first.check { raise "hell" } rescue nil }
    enabled.should eq true

    # We haven't used this one at all yet, but it should still push us over the
    # failure threshold.
    second.check { raise "hell" } rescue nil
    enabled.should eq false
  end
end
