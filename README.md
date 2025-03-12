# Youtex [![Build Status](https://github.com/patrykwozinski/youtex/workflows/CI/badge.svg)](https://github.com/patrykwozinski/youtex/actions) [![Hex pm](https://img.shields.io/hexpm/v/youtex.svg?style=flat)](https://hex.pm/packages/youtex)

A tool to list or to retrieve video transcriptions from YouTube.

## Installation

Add `youtex` to the list of dependencies inside `mix.exs`:

```elixir
def deps do
  [
    {:youtex, "~> 0.2.0"}
  ]
end
```

## Usage

Youtex provides a simple way to access YouTube video transcripts. Here are the main functions:

### List available transcripts

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

### Get a specific transcript

```elixir
Youtex.get_transcription("lxYFOM3UJzo")  # Defaults to English ("en")

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

### Specifying a language

```elixir
Youtex.get_transcription("lxYFOM3UJzo", "es")  # Get Spanish transcript
```

## Error Handling

Youtex returns tagged tuples for success and error cases:

```elixir
case Youtex.get_transcription("video_id") do
  {:ok, transcript} -> # Process transcript
  {:error, :not_found} -> # Handle missing transcript
end
```

### Bang Methods

If you don't need to pattern match `{:ok, data}` and `{:error, reason}`, there are also [trailing bang](https://hexdocs.pm/elixir/1.11.4/naming-conventions.html#trailing-bang-foo) versions for every function:

```elixir
# Raises an exception on error
transcripts = Youtex.list_transcripts!("lxYFOM3UJzo")
transcript = Youtex.get_transcription!("lxYFOM3UJzo")
```

## Data Structures

### Transcript

The `Youtex.Transcript` struct contains:

- `language_code`: Two-letter language code (e.g., "en", "es")
- `name`: Language name (e.g., "English", "Spanish")
- `generated`: Boolean indicating if transcript was auto-generated
- `url`: URL to the transcript resource
- `sentences`: List of sentence structs (when fetched with `get_transcription`)

### Sentence

The `Youtex.Transcript.Sentence` struct contains:

- `text`: The transcribed text
- `start`: Start time in seconds
- `duration`: Duration of the sentence in seconds

## Limitations

- Works only with videos that have available transcripts
- Language codes must match YouTube's language codes
- Requires Elixir ~> 1.11

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request