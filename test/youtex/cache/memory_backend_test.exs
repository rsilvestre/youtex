defmodule Youtex.Cache.MemoryBackendTest do
  use ExUnit.Case

  alias Youtex.Cache.MemoryBackend

  describe "init/1 with options validation" do
    test "validates options with NimbleOptions" do
      # Test with valid options
      assert {:ok, _state} = MemoryBackend.init(
        table_name: :test_memory_cache, 
        max_size: 500
      )
      
      # Test with invalid max_size (negative value)
      assert {:error, error_message} = MemoryBackend.init(max_size: -10)
      assert error_message =~ "expected a positive integer"
      
      # Test with invalid max_size type
      assert {:error, error_message} = MemoryBackend.init(max_size: "not_a_number")
      assert error_message =~ "expected a positive integer"
      
      # Test with invalid table_name type
      assert {:error, error_message} = MemoryBackend.init(table_name: "not_an_atom")
      assert error_message =~ "expected atom"
      
      # Test with unknown option
      assert {:error, error_message} = MemoryBackend.init(unknown_option: "value")
      assert error_message =~ "unknown options"
    end
  end
  
  describe "cache operations" do
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
      assert ^test_value = MemoryBackend.get(test_key, state)
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
      assert "value1" = MemoryBackend.get("key1", state)
      assert "value2" = MemoryBackend.get("key2", state)

      # Clear all entries
      :ok = MemoryBackend.clear(state)

      # Verify entries are gone
      assert nil == MemoryBackend.get("key1", state)
      assert nil == MemoryBackend.get("key2", state)
    end

    test "deletes entries", %{state: state} do
      :ok = MemoryBackend.put("key1", "value1", 10_000, state)
      assert "value1" = MemoryBackend.get("key1", state)

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
      assert "value" = MemoryBackend.get("valid", state)
    end
  end
end
