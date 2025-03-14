# Youtex [![Build Status](https://github.com/patrykwozinski/youtex/workflows/CI/badge.svg)](https://github.com/patrykwozinski/youtex/actions) [![Hex pm](https://img.shields.io/hexpm/v/youtex.svg?style=flat)](https://hex.pm/packages/youtex)

A tool to list or to retrieve video transcriptions from Youtube.

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

### List available transcripts

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

Youtex includes a flexible caching mechanism to improve performance and reduce API calls to YouTube. 
The cache system supports multiple backend options:

- **Memory**: In-memory cache using ETS tables (default, fast but not persistent)
- **Disk**: Persistent local storage using DETS (survives application restarts)
- **S3**: Cloud storage using AWS S3 (survives restarts and shareable across instances)
- **Cachex**: Distributed caching using Cachex (supports horizontal scaling across multiple nodes)

### Using Caching

If using Youtex as an application (included in your supervision tree), caching is automatically enabled. Otherwise, you need to manually start the cache:

```elixir
# Start cache
Youtex.start()
```

### Important Note for Disk Cache

When using the disk cache backend, you must ensure the cache directory exists before starting the application:

```bash
# Create the cache directory structure if it doesn't exist
mkdir -p priv/youtex_cache
```

For production deployments, this directory should be:
1. Created as part of your deployment process
2. Have proper file permissions for the user running the application
3. Be part of your release, but excluded from version control (add to .gitignore)

### Cache Configuration

You can configure cache behavior in your config:

```elixir
# In config/config.exs
config :youtex, 
  # General cache settings
  cache_ttl: 86_400_000,                    # TTL (time-to-live) - 1 day in milliseconds (default)
  cache_cleanup_interval: 3_600_000,        # Cleanup interval - every hour (default)
  
  # Configure which backend to use for each cache type
  cache_backends: %{
    # Memory backend (default)
    transcript_lists: %{
      backend: Youtex.Cache.MemoryBackend,
      backend_options: [
        table_name: :transcript_lists_cache,
        max_size: 1000                       # Max entries in memory
      ]
    },
    
    # Disk backend example
    transcript_contents: %{
      backend: Youtex.Cache.DiskBackend,
      backend_options: [
        table_name: :transcript_contents_cache, 
        cache_dir: "priv/youtex_cache",      # Directory for cache files
        max_size: 10000                      # Max entries on disk
      ]
    }
  }
```

All cache backend options are validated using NimbleOptions, providing:

1. Strong type checking and validation of configuration values
2. Comprehensive error messages for misconfiguration
3. Self-documented options with defaults

For example, if you provide an invalid value like a negative max_size:

```elixir
backend_options: [max_size: -100]  # Invalid negative value
```

You'll receive a helpful error message:
```
"expected a positive integer, got: -100"
```

#### Using S3 Backend

To use the S3 backend, you must add the following optional dependencies to your mix.exs:

```elixir
{:ex_aws, "~> 2.5"},
{:ex_aws_s3, "~> 2.4"},
{:sweet_xml, "~> 0.7"},
{:configparser_ex, "~> 4.0", optional: true}
```

Then configure the backend:

```elixir
config :youtex, 
  cache_backends: %{
    transcript_lists: %{
      backend: Youtex.Cache.S3Backend,
      backend_options: [
        bucket: "youtex-cache",              # S3 bucket name
        prefix: "transcripts",               # Prefix for objects
        region: "us-east-1"                  # AWS region
      ]
    }
  }
```

#### Using Cachex Backend for Distributed Caching

For applications with horizontal scaling, the Cachex backend provides distributed caching across multiple nodes. To use it, add the following optional dependency to your mix.exs:

```elixir
{:cachex, "~> 3.6"}
```

Then configure the backend:

```elixir
config :youtex, 
  cache_backends: %{
    transcript_lists: %{
      backend: Youtex.Cache.CachexBackend,
      backend_options: [
        table_name: :transcript_lists_cache,  # Cache name
        distributed: true,                    # Enable distributed mode
        default_ttl: :timer.hours(24),        # TTL for cache entries
        cleanup_interval: :timer.minutes(10), # How often to clean expired entries
        cachex_options: []                    # Additional Cachex options
      ]
    }
  }
```

To use distributed caching, you need to connect your Elixir nodes in a cluster. For example:

```elixir
# On node1@example.com
Node.connect(:"node2@example.com")

# On node2@example.com
Node.connect(:"node1@example.com") 
```

In a production environment, you would typically use a library like [libcluster](https://github.com/bitwalker/libcluster) to handle node discovery and connection automatically.

#### AWS Credentials for S3 Backend

When using the S3 backend, you need to provide AWS credentials in one of the following ways:

1. **Environment variables**:
   ```
   AWS_ACCESS_KEY_ID=your_key
   AWS_SECRET_ACCESS_KEY=your_secret
   ```

2. **AWS credentials file** at `~/.aws/credentials`:
   ```
   [default]
   aws_access_key_id = your_key
   aws_secret_access_key = your_secret
   ```

3. **Application config**:
   ```elixir
   # In config/config.exs
   config :ex_aws,
     access_key_id: "your_key",
     secret_access_key: "your_secret",
     region: "your-region"
   ```

ExAws automatically checks these locations in order. See the [ExAws documentation](https://github.com/ex-aws/ex_aws) for more configuration options.

### Cache Operations

```elixir
# Check if cache is enabled
Youtex.use_cache?()

# Clear cache
Youtex.clear_cache()
```

When caching is enabled, transcript lists and transcript contents are stored with their own TTL. The cache is automatically cleaned up periodically to prevent storage issues.

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

### Distributed Caching Considerations

When using the CachexBackend for horizontal scaling:

1. **Node Connectivity**: Ensure all nodes can communicate with each other through proper network configuration
2. **Node Discovery**: Use a library like [libcluster](https://github.com/bitwalker/libcluster) for reliable node discovery and connection
3. **Cache Consistency**: Be aware that there can be a short delay before cache updates propagate to all nodes
4. **Node Naming**: Nodes must have proper names (not anonymous) - use `--name node1@ip` or `--sname node1` when starting your application
5. **Cookie Configuration**: All nodes must share the same Erlang cookie for security

## Production Deployment

When deploying Youtex in a production environment, you need to take additional steps to ensure the cache system works correctly:

### Using Releases

Using Elixir releases is recommended for production deployments:

```bash
# Generate a release
MIX_ENV=prod mix release

# Run the release
_build/prod/rel/youtex/bin/youtex start
```

### Directory Structure

For disk caching to work in production with releases:

1. Create the `priv/youtex_cache` directory before starting the application:

```bash
# Create required directories in your production environment
mkdir -p /app/priv/youtex_cache
chmod 755 /app/priv/youtex_cache
```

2. Update your release configuration in `mix.exs` to include the `priv` directory:

```elixir
def project do
  [
    # ...
    releases: [
      youtex: [
        include_erts: true,
        include_executables_for: [:unix],
        applications: [
          youtex: :permanent
        ],
        # Copy priv directory to the release
        steps: [:assemble, :tar]
      ]
    ],
    # ...
  ]
end
```

### Runtime Configuration

Create a `config/releases.exs` file for runtime configuration:

```elixir
import Config

# Configure cache backends for production
config :youtex,
  cache_backends: %{
    transcript_lists: %{
      backend: Youtex.Cache.DiskBackend,
      backend_options: [
        table_name: :transcript_lists_cache,
        # Use absolute path in production
        cache_dir: "/app/priv/youtex_cache",
        max_size: 10000
      ]
    },
    transcript_contents: %{
      backend: Youtex.Cache.DiskBackend,
      backend_options: [
        table_name: :transcript_contents_cache,
        cache_dir: "/app/priv/youtex_cache",
        max_size: 10000
      ]
    }
  }

# For containerized deployments, you might want to use environment variables
if System.get_env("CACHE_DIR") do
  config :youtex,
    cache_backends: %{
      transcript_lists: %{
        backend: Youtex.Cache.DiskBackend,
        backend_options: [
          table_name: :transcript_lists_cache,
          cache_dir: System.get_env("CACHE_DIR", "/app/priv/youtex_cache"),
          max_size: String.to_integer(System.get_env("CACHE_MAX_SIZE", "10000"))
        ]
      },
      transcript_contents: %{
        backend: Youtex.Cache.DiskBackend,
        backend_options: [
          table_name: :transcript_contents_cache,
          cache_dir: System.get_env("CACHE_DIR", "/app/priv/youtex_cache"),
          max_size: String.to_integer(System.get_env("CACHE_MAX_SIZE", "10000"))
        ]
      }
    }
end

# For distributed deployments with Cachex
if System.get_env("USE_DISTRIBUTED_CACHE") == "true" do
  config :youtex,
    cache_backends: %{
      transcript_lists: %{
        backend: Youtex.Cache.CachexBackend,
        backend_options: [
          table_name: :transcript_lists_cache,
          distributed: true
        ]
      },
      transcript_contents: %{
        backend: Youtex.Cache.CachexBackend,
        backend_options: [
          table_name: :transcript_contents_cache,
          distributed: true
        ]
      }
    }
end
```

### Docker Deployment

If using Docker, ensure your Dockerfile includes steps to create the cache directory:

```dockerfile
FROM elixir:1.14-alpine AS build

# Build application...

FROM alpine:3.18 AS app

# Copy release from build stage...

# Create cache directory and set permissions
RUN mkdir -p /app/priv/youtex_cache && \
    chmod 755 /app/priv/youtex_cache

# Set working directory and run the release
WORKDIR /app
CMD ["bin/youtex", "start"]
```

### Kubernetes Deployment

When deploying to Kubernetes, use a persistent volume for the cache directory:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: youtex-cache-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: youtex
spec:
  replicas: 1
  selector:
    matchLabels:
      app: youtex
  template:
    metadata:
      labels:
        app: youtex
    spec:
      containers:
      - name: youtex
        image: your-registry/youtex:latest
        env:
        - name: CACHE_DIR
          value: "/app/priv/youtex_cache"
        volumeMounts:
        - name: cache-volume
          mountPath: /app/priv/youtex_cache
      volumes:
      - name: cache-volume
        persistentVolumeClaim:
          claimName: youtex-cache-pvc
```

## Future Improvements

Below is a list of potential improvements for the project:

### Cache System
- [ ] Implement proper supervision tree for cache components
- [ ] Add circuit breaker pattern for external backends
- [ ] Integrate Telemetry for cache metrics (hits, misses, performance)
- [ ] Enhance distributed cache consistency guarantees
- [ ] Implement exponential backoff for S3 operations

### Testing
- [ ] Add integration tests for distributed caching with multiple nodes
- [ ] Implement property-based testing using StreamData
- [ ] Create comprehensive tests for S3 backend
- [ ] Use ExVCR to mock HTTP requests for YouTube API

### Error Handling
- [ ] Replace generic error atoms with structured error types
- [ ] Implement cascading fallback strategies
- [ ] Add structured logging with context for debugging
- [ ] Introduce configurable timeouts for HTTP client

### Features
- [ ] Implement parallel fetching for multiple transcripts
- [ ] Add support for different transcript formats (SRT, VTT)
- [ ] Create text search functionality within transcripts
- [ ] Add configurable rate limiting for YouTube API calls
- [ ] Support for authenticated access to private/unlisted videos

### Performance
- [ ] Use streams for processing large transcripts
- [ ] Optimize cache serialization with more efficient protocols
- [ ] Implement connection pooling for HTTP requests
- [ ] Add lazy loading for transcript sentences

### Modern Practices
- [x] Use NimbleOptions for option validation
- [ ] Reorganize modules around domain concepts
- [ ] Add LiveBook examples for interactive documentation
- [ ] Implement runtime configuration validation

## License

Youtex is released under the MIT License. See the LICENSE file for details.

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