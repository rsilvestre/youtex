defmodule Youtex.Cache do
  @moduledoc """
  Provides caching functionality for transcript data to reduce API calls to YouTube.
  Uses ETS tables for fast in-memory caching with configurable TTL.
  """

  use GenServer
  use Youtex.Types

  alias Youtex.Transcript

  @transcript_list_table :youtex_transcript_lists
  @transcript_content_table :youtex_transcript_contents

  # Default TTL of 1 day in milliseconds
  @default_ttl 86_400_000

  # Maximum entries in each cache table (to prevent memory issues)
  @default_max_size 1000

  # Public API

  @doc """
  Starts the cache GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets transcript list from cache or returns nil if not found.
  """
  @spec get_transcript_list(video_id) :: {:ok, transcript_list} | nil
  def get_transcript_list(video_id) do
    case :ets.lookup(@transcript_list_table, video_id) do
      [{^video_id, data, expiry}] ->
        if System.system_time(:millisecond) < expiry do
          data
        else
          # Delete expired entry
          :ets.delete(@transcript_list_table, video_id)
          nil
        end

      [] ->
        nil
    end
  end

  @doc """
  Caches transcript list for a video ID.
  """
  @spec put_transcript_list(video_id, {:ok, transcript_list}) :: {:ok, transcript_list}
  def put_transcript_list(video_id, {:ok, _transcript_list} = data) do
    # Check if we're at max size and delete oldest item if needed
    max_size = Application.get_env(:youtex, :cache_max_size, @default_max_size)

    if :ets.info(@transcript_list_table, :size) >= max_size do
      delete_oldest(@transcript_list_table)
    end

    ttl = Application.get_env(:youtex, :cache_ttl, @default_ttl)
    expiry = System.system_time(:millisecond) + ttl
    :ets.insert(@transcript_list_table, {video_id, data, expiry})
    data
  end

  # Deletes the item with the earliest expiry time
  defp delete_oldest(table) do
    now = System.system_time(:millisecond)
    {key, _expiry} = find_oldest_entry(table, now)
    if key, do: :ets.delete(table, key), else: :ok
  end

  defp find_oldest_entry(table, now) do
    :ets.foldl(
      fn {key, _data, expiry}, {oldest_key, oldest_expiry} ->
        if expiry < oldest_expiry do
          {key, expiry}
        else
          {oldest_key, oldest_expiry}
        end
      end,
      {nil, now + @default_ttl * 2},
      table
    )
  end

  @doc """
  Gets transcript content from cache or returns nil if not found.
  """
  @spec get_transcript_content(String.t(), String.t()) :: {:ok, Transcript.t()} | nil
  def get_transcript_content(video_id, language) do
    key = "#{video_id}:#{language}"

    case :ets.lookup(@transcript_content_table, key) do
      [{^key, data, expiry}] ->
        if System.system_time(:millisecond) < expiry do
          data
        else
          :ets.delete(@transcript_content_table, key)
          nil
        end

      [] ->
        nil
    end
  end

  @doc """
  Caches transcript content for a video ID and language.
  """
  @spec put_transcript_content(String.t(), String.t(), {:ok, Transcript.t()}) ::
          {:ok, Transcript.t()}
  def put_transcript_content(video_id, language, {:ok, _transcript} = data) do
    # Check if we're at max size and delete oldest item if needed
    max_size = Application.get_env(:youtex, :cache_max_size, @default_max_size)

    if :ets.info(@transcript_content_table, :size) >= max_size do
      delete_oldest(@transcript_content_table)
    end

    ttl = Application.get_env(:youtex, :cache_ttl, @default_ttl)
    expiry = System.system_time(:millisecond) + ttl
    key = "#{video_id}:#{language}"
    :ets.insert(@transcript_content_table, {key, data, expiry})
    data
  end

  @doc """
  Clears all cached data.
  """
  def clear do
    :ets.delete_all_objects(@transcript_list_table)
    :ets.delete_all_objects(@transcript_content_table)
    :ok
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    tables = [
      {@transcript_list_table, [:set, :public, :named_table]},
      {@transcript_content_table, [:set, :public, :named_table]}
    ]

    for {name, opts} <- tables do
      :ets.new(name, opts)
    end

    # Schedule cleanup
    schedule_cleanup()

    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    now = System.system_time(:millisecond)

    # Clean up expired entries in transcript list table
    :ets.select_delete(@transcript_list_table, [
      {{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}
    ])

    # Clean up expired entries in transcript content table
    :ets.select_delete(@transcript_content_table, [
      {{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}
    ])

    schedule_cleanup()
    {:noreply, state}
  end

  defp schedule_cleanup do
    # Run cleanup every hour
    Process.send_after(self(), :cleanup, 3_600_000)
  end
end
