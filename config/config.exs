# In config/config.exs
import Config

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
