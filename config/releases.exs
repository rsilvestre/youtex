import Config

# Configure cache backends for production
config :youtex,
  # General cache settings
  cache_ttl: 86_400_000,                    # TTL (time-to-live) - 1 day in milliseconds (default)
  cache_cleanup_interval: 3_600_000,        # Cleanup interval - every hour (default)
  
  # Configure disk cache for production
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

# Allow overriding cache directory via environment variable
if cache_dir = System.get_env("CACHE_DIR") do
  config :youtex,
    cache_backends: %{
      transcript_lists: %{
        backend: Youtex.Cache.DiskBackend,
        backend_options: [
          table_name: :transcript_lists_cache,
          cache_dir: cache_dir,
          max_size: String.to_integer(System.get_env("CACHE_MAX_SIZE", "10000"))
        ]
      },
      transcript_contents: %{
        backend: Youtex.Cache.DiskBackend,
        backend_options: [
          table_name: :transcript_contents_cache,
          cache_dir: cache_dir,
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