defmodule Youtex.Cache.DiskBackendTest do
  use ExUnit.Case

  alias Youtex.Cache.DiskBackend

  @test_dir "test/tmp/cache"

  setup do
    # Ensure test directory exists
    File.mkdir_p!(@test_dir)

    # Initialize backend with test directory
    {:ok, state} =
      DiskBackend.init(
        table_name: :test_disk_cache,
        cache_dir: @test_dir
      )

    on_exit(fn ->
      # Clean up test files after test
      File.rm_rf!(@test_dir)
    end)

    {:ok, %{state: state}}
  end

  test "stores and retrieves values", %{state: state} do
    test_key = "test_key"
    test_value = %{data: "test_data"}
    ttl = 10_000

    # Store value
    assert :ok = DiskBackend.put(test_key, test_value, ttl, state)

    # Retrieve value
    case DiskBackend.get(test_key, state) do
      {:ok, value} ->
        # Due to serialization/deserialization, we need to compare contents
        assert value.data == test_value.data

      other ->
        flunk("Expected {:ok, value}, got: #{inspect(other)}")
    end
  end

  test "returns nil for non-existent keys", %{state: state} do
    assert nil == DiskBackend.get("non_existent", state)
  end

  test "handles expired entries", %{state: state} do
    test_key = "expired_key"
    test_value = %{data: "test_data"}
    # Very short TTL
    ttl = 1

    # Store value with short TTL
    :ok = DiskBackend.put(test_key, test_value, ttl, state)

    # Wait for expiry
    :timer.sleep(10)

    # Should return nil for expired key
    assert nil == DiskBackend.get(test_key, state)
  end

  test "clears all entries", %{state: state} do
    # Add multiple entries
    :ok = DiskBackend.put("key1", "value1", 10_000, state)
    :ok = DiskBackend.put("key2", "value2", 10_000, state)

    # Verify entries exist
    assert {:ok, "value1"} = DiskBackend.get("key1", state)
    assert {:ok, "value2"} = DiskBackend.get("key2", state)

    # Clear all entries
    :ok = DiskBackend.clear(state)

    # Verify entries are gone
    assert nil == DiskBackend.get("key1", state)
    assert nil == DiskBackend.get("key2", state)
  end

  test "deletes entries", %{state: state} do
    :ok = DiskBackend.put("key1", "value1", 10_000, state)
    assert {:ok, "value1"} = DiskBackend.get("key1", state)

    :ok = DiskBackend.delete("key1", state)
    assert nil == DiskBackend.get("key1", state)
  end

  test "cleans up expired entries", %{state: state} do
    # Add an entry that will expire
    :ok = DiskBackend.put("expired", "value", 1, state)
    # Add an entry that won't expire
    :ok = DiskBackend.put("valid", "value", 10_000, state)

    # Wait for first entry to expire
    :timer.sleep(10)

    # Run cleanup
    :ok = DiskBackend.cleanup(state)

    # Expired entry should be gone, valid entry should remain
    assert nil == DiskBackend.get("expired", state)
    assert {:ok, "value"} = DiskBackend.get("valid", state)
  end
end
