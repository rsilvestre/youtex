defmodule Youtex.Cache.MemoryBackendTest do
  use ExUnit.Case

  alias Youtex.Cache.MemoryBackend

  setup do
    {:ok, state} = MemoryBackend.init(table_name: :test_memory_cache)
    {:ok, %{state: state}}
  end

  test "stores and retrieves values", %{state: state} do
    test_key = "test_key"
    test_value = %{data: "test_data"}
    ttl = 10_000

    # Store value
    assert :ok = MemoryBackend.put(test_key, test_value, ttl, state)

    # Retrieve value
    assert {:ok, ^test_value} = MemoryBackend.get(test_key, state)
  end

  test "returns nil for non-existent keys", %{state: state} do
    assert nil == MemoryBackend.get("non_existent", state)
  end

  test "handles expired entries", %{state: state} do
    test_key = "expired_key"
    test_value = %{data: "test_data"}
    # Very short TTL
    ttl = 1

    # Store value with short TTL
    :ok = MemoryBackend.put(test_key, test_value, ttl, state)

    # Wait for expiry
    :timer.sleep(10)

    # Should return nil for expired key
    assert nil == MemoryBackend.get(test_key, state)
  end

  test "clears all entries", %{state: state} do
    # Add multiple entries
    :ok = MemoryBackend.put("key1", "value1", 10_000, state)
    :ok = MemoryBackend.put("key2", "value2", 10_000, state)

    # Verify entries exist
    assert {:ok, "value1"} = MemoryBackend.get("key1", state)
    assert {:ok, "value2"} = MemoryBackend.get("key2", state)

    # Clear all entries
    :ok = MemoryBackend.clear(state)

    # Verify entries are gone
    assert nil == MemoryBackend.get("key1", state)
    assert nil == MemoryBackend.get("key2", state)
  end

  test "deletes entries", %{state: state} do
    :ok = MemoryBackend.put("key1", "value1", 10_000, state)
    assert {:ok, "value1"} = MemoryBackend.get("key1", state)

    :ok = MemoryBackend.delete("key1", state)
    assert nil == MemoryBackend.get("key1", state)
  end

  test "cleans up expired entries", %{state: state} do
    # Add an entry that will expire
    :ok = MemoryBackend.put("expired", "value", 1, state)
    # Add an entry that won't expire
    :ok = MemoryBackend.put("valid", "value", 10_000, state)

    # Wait for first entry to expire
    :timer.sleep(10)

    # Run cleanup
    :ok = MemoryBackend.cleanup(state)

    # Expired entry should be gone, valid entry should remain
    assert nil == MemoryBackend.get("expired", state)
    assert {:ok, "value"} = MemoryBackend.get("valid", state)
  end
end
