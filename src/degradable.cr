require "redis"

abstract class Degradable
  VERSION = "0.1.0"

  abstract def checked : Int
  abstract def failed : Int

  def initialize(
    @failure_threshold : Float64,
    @minimum : Int32 = 1_000,
    &@failure_handler
  )
  end

  def check
    checked_count = checked

    begin
      yield
    rescue ex
      failed_count = failed
      if checked_count >= @minimum && failed_count / checked_count >= @failure_threshold
        @failure_handler.call
      end
      raise ex
    end
  end

  class Memory < Degradable
    # Making these atomic so it'll be safe in a multithreaded application.
    @degradable_requests : Atomic(UInt64) = Atomic.new(0u64)
    @degradable_failures : Atomic(UInt64) = Atomic.new(0u64)

    def checked : Int
      old_value = @degradable_requests.add 1

      # Atomic#add returns the value before the add operation, but the contract
      # of this method is that the total number of checks including this one is
      # returned, so we add it ourselves here.
      old_value + 1
    end

    def failed : Int
      old_value = @degradable_failures.add 1

      # Atomic#add returns the value before the add operation, but the contract
      # of this method is that the total number of checks including this one is
      # returned, so we add it ourselves here.
      old_value + 1
    end
  end

  class Redis < Degradable
    def initialize(
      feature : String,
      failure_threshold : Float64,
      @redis : ::Redis::Client,
      minimum : Int32 = 1_000,
      &failure_handler
    )
      @check_key = "degradable:#{feature}:checks"
      @failure_key = "degradable:#{feature}:failures"

      super(
        failure_threshold: failure_threshold,
        minimum: minimum,
        &failure_handler
      )
    end

    def checked : Int
      @redis.incr @check_key
    end

    def failed : Int
      @redis.incr @failure_key
    end
  end
end
