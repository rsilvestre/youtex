# Youtex [![Build Status](https://github.com/patrykwozinski/youtex/workflows/CI/badge.svg)](https://github.com/patrykwozinski/youtex/actions) [![Hex pm](https://img.shields.io/hexpm/v/youtex.svg?style=flat)](https://hex.pm/packages/youtex)

A tool to list or to retrieve video transcriptions from Youtube. Youtex allows you to easily fetch and parse subtitles/closed captions from YouTube videos.

## Installation

Add `youtex` to the list of dependencies inside `mix.exs`:

```elixir
def deps do
  [
    {:youtex, "~> 0.2.0"}
  ]
end
```

This package requires Elixir 1.15 or later and has the following dependencies:
- elixir_xml_to_map ~> 3.1
- poison ~> 6.0
- httpoison ~> 2.2
- typed_struct ~> 0.3

## Usage

There are 2 main functions for fetching transcripts:

### List Available Transcripts

**Youtex.list_transcripts(video_id)**

Lists all available transcripts for a given YouTube video.

```elixir
Youtex.list_transcripts("lxYFOM3UJzo")

{:ok,
 [
   %Youtex.Transcript{
     generated: false,
     language_code: "en",
     name: "English",
     sentences: [],
     url: "https://www.youtube.com/api/timedtext..."
   },
   %Youtex.Transcript{...},
   ...
 ]}
```

### Get Specific Transcript

**Youtex.get_transcription(video_id, language \\\\ "en")**

Fetches a specific transcript by language code (defaults to "en" for English).

```elixir
Youtex.get_transcription("lxYFOM3UJzo")

{:ok,
 %Youtex.Transcript{
   generated: false,
   language_code: "en",
   name: "English",
   sentences: [
     %Youtex.Transcript.Sentence{
       duration: 9.3,
       start: 9.53,
       text: "I remember like my first computer was a\nPentium 100 megahertz. I would be in"
     },
     %Youtex.Transcript.Sentence{...},
     ...
   ],
   url: "https://www.youtube.com/api/timedtext..."
 }}
```

### Error Handling

All functions return either:
- `{:ok, result}` for successful operations
- `{:error, reason}` when something goes wrong (typically `:not_found`)

### Bang Functions

If you don't need to pattern match `{:ok, data}` and `{:error, reason}`, there are also [trailing bang](https://hexdocs.pm/elixir/naming-conventions.html#trailing-bang-foo) versions for every function:

```elixir
# Returns the list directly or raises an exception
transcripts = Youtex.list_transcripts!("lxYFOM3UJzo")

# Returns the transcript directly or raises an exception
transcript = Youtex.get_transcription!("lxYFOM3UJzo", "en")
```

## Caching

Youtex includes a built-in caching mechanism to improve performance and reduce API calls to YouTube. The cache is implemented using ETS tables and is automatically enabled when used as an application.

### Using Caching

If using Youtex as an application (included in your supervision tree), caching is automatically enabled. Otherwise, you need to manually start the cache:

```elixir
# Start cache
Youtex.start()
```

### Cache Configuration

You can configure cache behavior in your config:

```elixir
# In config/config.exs
config :youtex, 
  # TTL (time-to-live) - 1 day in milliseconds (default)
  cache_ttl: 86_400_000,
  
  # Maximum number of entries in each cache table (default: 1000)
  cache_max_size: 1000
```

### Cache Operations

```elixir
# Check if cache is enabled
Youtex.use_cache?()

# Clear cache
Youtex.clear_cache()
```

When caching is enabled, transcript lists and transcript contents are stored separately with their own TTL. The cache is automatically cleaned up periodically to prevent memory issues.

## Data Structures

### Youtex.Transcript

The main transcript structure containing:
- `language_code`: ISO language code (e.g., "en", "fr")  
- `name`: Human-readable language name
- `generated`: Whether the transcript was auto-generated
- `sentences`: List of transcript sentences (empty when listing)
- `url`: API URL to fetch the transcript content

### Youtex.Transcript.Sentence

Each sentence in a transcript contains:
- `text`: The actual transcript text
- `start`: Starting time in seconds
- `duration`: Duration of the sentence in seconds

## Examples

### Fetching and processing transcripts

```elixir
# Get transcript for a video and extract text
defmodule TranscriptProcessor do
  def get_plain_text(video_id, language \\ "en") do
    case Youtex.get_transcription(video_id, language) do
      {:ok, transcript} ->
        sentences = Enum.map(transcript.sentences, & &1.text)
        {:ok, Enum.join(sentences, " ")}
      
      {:error, reason} -> 
        {:error, reason}
    end
  end
  
  def get_timestamped_text(video_id, language \\ "en") do
    case Youtex.get_transcription(video_id, language) do
      {:ok, transcript} ->
        formatted = Enum.map(transcript.sentences, fn sentence ->
          timestamp = format_timestamp(sentence.start)
          "#{timestamp}: #{sentence.text}"
        end)
        
        {:ok, formatted}
      
      {:error, reason} -> 
        {:error, reason}
    end
  end
  
  defp format_timestamp(seconds) do
    minutes = div(floor(seconds), 60)
    remaining_seconds = rem(floor(seconds), 60)
    
    "#{String.pad_leading(Integer.to_string(minutes), 2, "0")}:#{String.pad_leading(Integer.to_string(remaining_seconds), 2, "0")}"
  end
end

# Usage:
{:ok, plain_text} = TranscriptProcessor.get_plain_text("lxYFOM3UJzo")
{:ok, timestamped} = TranscriptProcessor.get_timestamped_text("lxYFOM3UJzo")
```

## Requirements

- Elixir ~> 1.15

## Troubleshooting

### Common Issues

1. **Transcript Not Found**
   ```
   {:error, :not_found}
   ```
   This can happen when:
   - The video ID is incorrect
   - The requested language is not available
   - The video has no transcripts/captions available
   
2. **Network Errors**
   If you're experiencing network issues, ensure you have a working internet connection. The library depends on HTTPoison for making requests to YouTube.

### Limitations

- This library cannot access private or unlisted videos that require authentication
- YouTube's API structure might change, which could impact functionality
- Some auto-generated transcripts may have poor quality or accuracy
- YouTube rate limiting may apply when making many requests in a short time

## License

Youtex is released under the MIT License. See the LICENSE file for details.

