defmodule Youtex.Cache do
  @moduledoc """
  Provides caching functionality for transcript data to reduce API calls to YouTube.

  This module uses YouCache internally but maintains the original API.
  """

  use YouCache,
    registries: [:transcript_lists, :transcript_contents]

  use Youtex.Types

  alias Youtex.Transcript

  # Default TTL of 1 day in milliseconds
  @default_ttl 86_400_000

  # Public API (maintains original interface)

  @doc """
  Gets transcript list from cache or returns nil if not found.
  """
  @spec get_transcript_list(video_id) :: {:ok, transcript_list} | {:miss, nil} | {:error, term()}
  def get_transcript_list(video_id) do
    get(:transcript_lists, video_id)
  end

  @doc """
  Caches transcript list for a video ID.
  """
  @spec put_transcript_list(video_id, {:ok, transcript_list}) :: {:ok, transcript_list}
  def put_transcript_list(video_id, {:ok, transcript_list} = data) do
    ttl = get_ttl()
    # Store just the list, not the full {:ok, list} tuple to match test expectations
    put(:transcript_lists, video_id, transcript_list, ttl)
    data
  end

  @doc """
  Gets transcript content from cache or returns nil if not found.
  """
  @spec get_transcript_content(String.t(), String.t()) :: {:ok, Transcript.t()} | {:miss, nil} | {:error, term()}
  def get_transcript_content(video_id, language) do
    key = "#{video_id}:#{language}"
    get(:transcript_contents, key)
  end

  @doc """
  Caches transcript content for a video ID and language.
  """
  @spec put_transcript_content(String.t(), String.t(), {:ok, Transcript.t()}) ::
          {:ok, Transcript.t()}
  def put_transcript_content(video_id, language, {:ok, transcript} = data) do
    key = "#{video_id}:#{language}"
    ttl = get_ttl()
    # Store just the transcript, not the full {:ok, transcript} tuple to match test expectations
    put(:transcript_contents, key, transcript, ttl)
    data
  end

  # Note: Using the clear/0 function from YouCache
  # which is already defined by `use YouCache`

  # Helper function to maintain original behavior
  defp get_ttl do
    Application.get_env(:youtex, :cache_ttl, @default_ttl)
  end
end