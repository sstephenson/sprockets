require 'sprockets/base'

module Sprockets
  # `Cached` is a special cached version of `Environment`.
  #
  # The expection is that all of its file system methods are cached
  # for the instances lifetime. This makes `Cached` much faster. This
  # behavior is ideal in production environments where the file system
  # is immutable.
  #
  # `Cached` should not be initialized directly. Instead use
  # `Environment#cached`.
  class CachedEnvironment < Base
    def initialize(environment)
      @environment = environment

      # Copy environment attributes
      @logger            = environment.logger
      @context_class     = environment.context_class
      @cache             = environment.cache
      @digest_class      = environment.digest_class
      @version           = environment.version
      @root              = environment.root
      @paths             = environment.paths.dup
      @extensions        = environment.extensions.dup
      @extension_pattern = environment.extension_pattern
      @mime_types        = environment.mime_types
      @engines           = environment.engines
      @engine_mime_types = environment.engine_mime_types.dup
      @engine_extensions = environment.engine_extensions.dup
      @preprocessors     = environment.preprocessors
      @postprocessors    = environment.postprocessors
      @bundle_processors = environment.bundle_processors
      @compressors       = environment.compressors

      @stats    = Hash.new { |h, k| h[k] = _stat(k) }
      @entries  = Hash.new { |h, k| h[k] = _entries(k) }
    end

    # No-op return self as cached environment.
    def cached
      self
    end
    alias_method :index, :cached

    # Internal: Cache Environment#entries
    alias_method :_entries, :entries
    def entries(path)
      @entries[path]
    end

    # Internal: Cache Environment#stat
    alias_method :_stat, :stat
    def stat(path)
      @stats[path]
    end

    protected
      # Cache is immutable, any methods that try to clear the cache
      # should bomb.
      def expire_cache!
        raise TypeError, "can't modify immutable cached environment"
      end

      def asset_hash_cache_key(filename, digest, bundle)
        [
          'asset-hash',
          VERSION,
          self.version,
          filename,
          digest,
          bundle
        ]
      end

      def asset_digest_cache_key(filename, bundle)
        [
          'asset-digest',
          VERSION,
          self.version,
          filename,
          bundle,
          file_hexdigest(filename),
          self.paths
        ]
      end

      def build_asset_hash_for_digest(*args)
        cache.fetch(asset_hash_cache_key(*args)) do
          super
        end
      end

      # Cache asset building in memory and in persisted cache.
      def build_asset_hash(filename, bundle = true)
        digest_key = asset_digest_cache_key(filename, bundle)

        if digest = cache._get(digest_key)
          hash_key = asset_hash_cache_key(filename, digest, bundle)

          if hash = cache._get(hash_key)
            digest, paths = hash[:metadata].values_at(:dependency_digest, :dependency_paths)
            if dependencies_hexdigest(paths) == digest
              return hash
            end
          end
        end

        if hash = super
          cache._set(digest_key, hash[:digest])

          # Push into asset digest cache
          hash_key = asset_hash_cache_key(filename, hash[:digest], bundle)
          # cache._set(hash_key, hash)
          cache.fetch(hash_key) { hash }

          return hash
        end

        nil
      end
  end
end
