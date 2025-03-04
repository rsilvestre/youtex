defmodule Youtex do
  @moduledoc """
  Main module with functions to list and to retrieve transcriptions.
  """

  use Youtex.Types

  alias Youtex.{Cache, Transcript, Video}
  alias Youtex.Transcript.Fetch

  @default_language "en"

  @doc """
  Starts the Youtex application with caching enabled.
  Call this function when you want to use caching for transcripts outside
  of a supervision tree.

  ## Options

  * `:backends` - A map of cache backend configurations (optional)
  * `:ttl` - Cache TTL in milliseconds (optional)

  ## Examples

      # Start with default memory backend
      Youtex.start()
      
      # Start with custom configuration
      Youtex.start(backends: %{
        transcript_lists: %{
          backend: Youtex.Cache.DiskBackend,
          backend_options: [cache_dir: "my_cache_dir"]
        }
      })
  """
  def start(opts \\ []) do
    # If specific backends are provided, update application env
    if backend_config = Keyword.get(opts, :backends) do
      Application.put_env(:youtex, :cache_backends, backend_config)
    end

    # If TTL is provided, update application env
    if ttl = Keyword.get(opts, :ttl) do
      Application.put_env(:youtex, :cache_ttl, ttl)
    end

    Cache.start_link(Keyword.get(opts, :cache_opts, []))
  end

  @doc """
  Lists available transcripts for a YouTube video.
  Returns a list of available transcripts with metadata (no content).
  """
  @spec list_transcripts(video_id) :: transcripts_found | error
  def list_transcripts(video_id) do
    case use_cache?() && Cache.get_transcript_list(video_id) do
      nil ->
        # Not in cache, fetch and cache it
        fetch_and_cache_transcript_list(video_id)

      cached_result ->
        cached_result
    end
  end

  defp fetch_and_cache_transcript_list(video_id) do
    result =
      video_id
      |> Video.new()
      |> Fetch.transcript_list()

    case result do
      {:ok, _} = ok_result ->
        if use_cache?(), do: Cache.put_transcript_list(video_id, ok_result)
        ok_result

      error ->
        error
    end
  end

  @doc """
  Lists available transcripts for a YouTube video.
  Like `list_transcripts/1` but raises an exception on error.
  """
  @spec list_transcripts!(video_id) :: transcript_list
  def list_transcripts!(video_id) do
    case list_transcripts(video_id) do
      {:ok, transcript_list} -> transcript_list
      {:error, reason} -> raise RuntimeError, message: to_string(reason)
    end
  end

  @doc """
  Gets a specific transcript for a YouTube video.
  Returns a transcript with full content (sentences with text and timing).
  """
  @spec get_transcription(video_id, language) :: transcript_found | error
  def get_transcription(video_id, language \\ @default_language) do
    case use_cache?() && Cache.get_transcript_content(video_id, language) do
      nil ->
        # Not in cache, fetch and cache it
        fetch_and_cache_transcript_content(video_id, language)

      cached_result ->
        cached_result
    end
  end

  defp fetch_and_cache_transcript_content(video_id, language) do
    result = do_get_transcription(video_id, language)

    case result do
      {:ok, _} = ok_result ->
        if use_cache?(), do: Cache.put_transcript_content(video_id, language, ok_result)
        ok_result

      error ->
        error
    end
  end

  defp do_get_transcription(video_id, language) do
    with {:ok, transcript_list} <- list_transcripts(video_id),
         {:ok, transcript} <- Transcript.for_language(transcript_list, language) do
      Fetch.transcript_sentences(transcript)
    else
      error -> error
    end
  end

  @doc """
  Gets a specific transcript for a YouTube video.
  Like `get_transcription/2` but raises an exception on error.
  """
  @spec get_transcription!(video_id, language) :: Transcript.t()
  def get_transcription!(video_id, language \\ @default_language) do
    case get_transcription(video_id, language) do
      {:ok, transcript} -> transcript
      {:error, reason} -> raise RuntimeError, message: to_string(reason)
    end
  end

  @doc """
  Clears all cached transcripts.
  """
  def clear_cache do
    if use_cache?() do
      Cache.clear()
    else
      {:error, :cache_not_started}
    end
  end

  @doc """
  Checks if caching is enabled.
  """
  def use_cache? do
    case Process.whereis(Cache) do
      nil -> false
      _pid -> true
    end
  end
end
