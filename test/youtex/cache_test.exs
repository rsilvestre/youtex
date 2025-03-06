defmodule Youtex.CacheTest do
  use ExUnit.Case
  alias Youtex.{Cache, Transcript}

  setup do
    # Start cache for testing or use existing
    case Process.whereis(Cache) do
      nil ->
        # Choose backend based on available dependencies (MemoryBackend or CachexBackend)
        backend = 
          if Code.ensure_loaded?(Cachex) do
            Youtex.Cache.CachexBackend
          else
            Youtex.Cache.MemoryBackend
          end
        
        opts = [
          backends: %{
            transcript_lists: %{
              backend: backend,
              backend_options: [table_name: :test_transcript_lists]
            },
            transcript_contents: %{
              backend: backend,
              backend_options: [table_name: :test_transcript_contents]
            }
          }
        ]

        {:ok, _pid} = Cache.start_link(opts)

      _pid ->
        :ok
    end

    # Clear cache before each test
    Cache.clear()
    
    # Pass the backend type used to tests
    backend_type = 
      if Code.ensure_loaded?(Cachex) do
        :cachex
      else
        :memory
      end
    {:ok, %{backend_type: backend_type}}
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
    case Cache.get_transcript_list(video_id) do
      {:ok, cached_list} ->
        assert cached_list == transcript_list

      other ->
        flunk("Expected {:ok, list}, got: #{inspect(other)}")
    end
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
    case Cache.get_transcript_content(video_id, language) do
      {:ok, cached} ->
        assert cached == transcript

      other ->
        flunk("Expected {:ok, transcript}, got: #{inspect(other)}")
    end
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

    # Verify cache has the item
    case Cache.get_transcript_list(video_id) do
      {:ok, cached_list} ->
        assert cached_list == transcript_list

      other ->
        flunk("Expected {:ok, list}, got: #{inspect(other)}")
    end

    # Clear cache
    Cache.clear()

    # Verify item is gone
    assert Cache.get_transcript_list(video_id) == nil
  end
  
  @tag :cachex
  test "runs with Cachex backend if available", %{backend_type: backend_type} do
    # Skip if Cachex is not available
    if backend_type != :cachex do
      # Just return early from the test if Cachex isn't available
      IO.puts("Skipping Cachex test - Cachex not available")
      assert true
    else
      # This test verifies that the code can run using the Cachex backend
      # by storing and retrieving a value
      video_id = "cachex_test_video"
      
      transcript_list = [
        %Transcript{
          language_code: "en",
          name: "English",
          generated: false,
          sentences: [],
          url: "https://example.com/cachex_test"
        }
      ]
      
      # Cache the transcript list
      Cache.put_transcript_list(video_id, {:ok, transcript_list})
      
      # Retrieve from cache
      case Cache.get_transcript_list(video_id) do
        {:ok, cached_list} ->
          assert cached_list == transcript_list
          
        other ->
          flunk("Expected {:ok, list}, got: #{inspect(other)}")
      end
    end
  end
end