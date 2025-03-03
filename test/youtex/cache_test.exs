defmodule Youtex.CacheTest do
  use ExUnit.Case
  alias Youtex.{Cache, Transcript}

  setup do
    # Start cache for testing or use existing
    case Process.whereis(Cache) do
      nil ->
        {:ok, _pid} = Cache.start_link()

      _pid ->
        :ok
    end

    # Clear cache before each test
    Cache.clear()
    :ok
  end

  test "caches and retrieves transcript lists" do
    video_id = "test_video_id"

    transcript_list = [
      %Transcript{
        language_code: "en",
        name: "English",
        generated: false,
        sentences: [],
        url: "https://example.com/transcript"
      }
    ]

    # Cache the transcript list
    Cache.put_transcript_list(video_id, {:ok, transcript_list})

    # Retrieve from cache
    assert Cache.get_transcript_list(video_id) == {:ok, transcript_list}
  end

  test "caches and retrieves transcript content" do
    video_id = "test_video_id"
    language = "en"

    sentences = [
      %Transcript.Sentence{
        text: "Test sentence",
        start: 0.0,
        duration: 1.0
      }
    ]

    transcript = %Transcript{
      language_code: "en",
      name: "English",
      generated: false,
      sentences: sentences,
      url: "https://example.com/transcript"
    }

    # Cache the transcript content
    Cache.put_transcript_content(video_id, language, {:ok, transcript})

    # Retrieve from cache
    assert Cache.get_transcript_content(video_id, language) == {:ok, transcript}
  end

  test "returns nil for non-existent items" do
    assert Cache.get_transcript_list("non_existent_id") == nil
    assert Cache.get_transcript_content("non_existent_id", "en") == nil
  end

  test "clear removes all cached items" do
    video_id = "test_video_id"

    transcript_list = [
      %Transcript{
        language_code: "en",
        name: "English",
        generated: false,
        sentences: [],
        url: "url"
      }
    ]

    Cache.put_transcript_list(video_id, {:ok, transcript_list})
    assert Cache.get_transcript_list(video_id) == {:ok, transcript_list}

    Cache.clear()
    assert Cache.get_transcript_list(video_id) == nil
  end
end
