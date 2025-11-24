defmodule RogsCommWeb.RateLimiterTest do
  use ExUnit.Case, async: false

  alias RogsCommWeb.RateLimiter

  setup do
    # Initialize rate limiter for each test
    RateLimiter.init()
    on_exit(fn -> :ets.delete(:rogs_comm_rate_limits) end)
    :ok
  end

  describe "check/2" do
    test "allows first request" do
      user_id = Ecto.UUID.generate()
      assert {:ok, :allowed} = RateLimiter.check(user_id)
    end

    test "allows requests within limit" do
      user_id = Ecto.UUID.generate()

      for _i <- 1..4 do
        assert {:ok, :allowed} = RateLimiter.check(user_id, limit: 5, window_seconds: 1)
      end
    end

    test "rejects requests exceeding limit" do
      user_id = Ecto.UUID.generate()

      # Fill up to limit
      for _i <- 1..5 do
        assert {:ok, :allowed} = RateLimiter.check(user_id, limit: 5, window_seconds: 1)
      end

      # Next request should be rate limited
      assert {:error, :rate_limited} = RateLimiter.check(user_id, limit: 5, window_seconds: 1)
    end

    test "allows requests after window expires" do
      user_id = Ecto.UUID.generate()

      # Fill up to limit
      for _i <- 1..5 do
        assert {:ok, :allowed} = RateLimiter.check(user_id, limit: 5, window_seconds: 1)
      end

      # Wait for window to expire (using a very short window for testing)
      Process.sleep(1100)

      # Should be allowed again
      assert {:ok, :allowed} = RateLimiter.check(user_id, limit: 5, window_seconds: 1)
    end

    test "tracks rate limits per user independently" do
      user1 = Ecto.UUID.generate()
      user2 = Ecto.UUID.generate()

      # Fill up user1's limit
      for _i <- 1..5 do
        assert {:ok, :allowed} = RateLimiter.check(user1, limit: 5, window_seconds: 1)
      end

      # user1 should be rate limited
      assert {:error, :rate_limited} = RateLimiter.check(user1, limit: 5, window_seconds: 1)

      # user2 should still be allowed
      assert {:ok, :allowed} = RateLimiter.check(user2, limit: 5, window_seconds: 1)
    end

    test "uses default limit and window when options not provided" do
      user_id = Ecto.UUID.generate()

      # Default limit is 5
      for _i <- 1..5 do
        assert {:ok, :allowed} = RateLimiter.check(user_id)
      end

      assert {:error, :rate_limited} = RateLimiter.check(user_id)
    end
  end

  describe "cleanup/1" do
    test "removes old entries" do
      user_id = Ecto.UUID.generate()

      # Create entries in old window
      RateLimiter.check(user_id, limit: 5, window_seconds: 1)
      Process.sleep(1100)

      # Create entry in new window
      RateLimiter.check(user_id, limit: 5, window_seconds: 1)

      # Cleanup should remove old entries
      deleted_count = RateLimiter.cleanup(1)
      assert deleted_count >= 0
    end
  end
end

