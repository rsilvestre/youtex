defmodule Youtex.Cache.DiskBackend do
  @moduledoc """
  Disk-based cache backend implementation.

  This backend stores cache entries on disk, making them persistent across application restarts.
  It uses DETS tables under the hood, which are disk-based implementations of ETS.
  """

  @behaviour Youtex.Cache.Backend

  @default_cache_dir "priv/youtex_cache"
  # More entries for disk cache
  @default_max_size 10_000

  # Backend Implementation

  @impl true
  def init(options) do
    table_name = Keyword.get(options, :table_name, :youtex_disk_cache)
    cache_dir = Keyword.get(options, :cache_dir, @default_cache_dir)
    max_size = Keyword.get(options, :max_size, @default_max_size)

    # Ensure cache directory exists
    File.mkdir_p!(cache_dir)

    file_path = Path.join(cache_dir, "#{table_name}.dets")

    case :dets.open_file(table_name,
           type: :set,
           file: to_charlist(file_path),
           # Save every minute
           auto_save: 60_000,
           ram_file: false
         ) do
      {:ok, table} ->
        {:ok, %{table: table, max_size: max_size}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def put(key, value, ttl, state) do
    # Check if we're at max size and delete oldest item if needed
    count_entries(state.table)
    |> case do
      {:ok, size} when size >= state.max_size ->
        delete_oldest_entries(state.table, size - state.max_size + 1)

      _ ->
        :ok
    end

    # Serialize value to ensure it's compatible with DETS
    serialized_value = serialize(value)
    expiry = System.system_time(:millisecond) + ttl

    case :dets.insert(state.table, {key, serialized_value, expiry}) do
      :ok -> :ok
      error -> error
    end
  end

  @impl true
  def get(key, state) do
    case :dets.lookup(state.table, key) do
      [{^key, serialized_value, expiry}] ->
        now = System.system_time(:millisecond)

        if now < expiry do
          {:ok, deserialize(serialized_value)}
        else
          # Delete expired entry
          :dets.delete(state.table, key)
          nil
        end

      [] ->
        nil

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl true
  def delete(key, state) do
    :dets.delete(state.table, key)
  end

  @impl true
  def clear(state) do
    :dets.delete_all_objects(state.table)
  end

  @impl true
  def cleanup(state) do
    now = System.system_time(:millisecond)

    # We need to manually find and delete expired entries
    # as DETS doesn't support select_delete like ETS
    :dets.foldl(
      fn {key, _value, expiry} = _entry, acc ->
        if expiry < now do
          :dets.delete(state.table, key)
        end

        acc
      end,
      0,
      state.table
    )

    :ok
  end

  # Helper functions

  defp count_entries(table) do
    try do
      count = :dets.info(table, :size)
      {:ok, count}
    rescue
      _ -> {:error, :count_failed}
    end
  end

  defp delete_oldest_entries(table, count) do
    # Find all entries with their expiry times
    entries =
      :dets.foldl(
        fn {key, _value, expiry}, acc ->
          [{key, expiry} | acc]
        end,
        [],
        table
      )

    # Sort by expiry (oldest first)
    entries
    |> Enum.sort_by(fn {_key, expiry} -> expiry end)
    |> Enum.take(count)
    |> Enum.each(fn {key, _expiry} ->
      :dets.delete(table, key)
    end)

    :ok
  end

  # Serialization helpers
  defp serialize(value) do
    :erlang.term_to_binary(value)
  end

  defp deserialize(binary) do
    :erlang.binary_to_term(binary)
  end
end
