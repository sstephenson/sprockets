require 'sprockets/base'

module Sprockets
  # `Index` is a special cached version of `Environment`.
  #
  # The expection is that all of its file system methods are cached
  # for the instances lifetime. This makes `Index` much faster. This
  # behavior is ideal in production environments where the file system
  # is immutable.
  #
  # `Index` should not be initialized directly. Instead use
  # `Environment#index`.
  class Index < Base
    def initialize(environment)
      # Copy environment attributes
      @logger            = environment.logger
      @context_class     = environment.context_class
      @cache             = environment.cache
      @trail             = environment.trail.index
      @static_root       = environment.static_root
      @digest            = environment.digest
      @digest_class      = environment.digest_class
      @version           = environment.version
      @mime_types        = environment.mime_types
      @engines           = environment.engines
      @preprocessors     = environment.preprocessors
      @postprocessors    = environment.postprocessors
      @bundle_processors = environment.bundle_processors

      # Initialize caches
      @assets  = {}
      @digests = {}
    end

    # No-op return self as index
    def index
      self
    end

    # Cache calls to `file_digest`
    def file_digest(pathname, data = nil)
      memoize(@digests, pathname.to_s) { super }
    end

    # Cache `find_asset` calls
    def find_asset(path, options = {})
      if asset = @assets[path.to_s]
        asset
      elsif asset = super
        # Cache at logical path and expanded path
        @assets[path.to_s] = @assets[asset.pathname.to_s] = asset
        asset
      end
    end

    protected
      # Index is immutable, any methods that try to clear the cache
      # should bomb.
      def expire_index!
        raise TypeError, "can't modify immutable index"
      end

      # Cache asset building in memory and in persisted cache.
      def build_asset(path, pathname, options)
        # Memory cache
        memoize(@assets, pathname.to_s) do
          # Persisted cache
          cache_asset(pathname.to_s) do
            super
          end
        end
      end

    private
      # Simple memoize helper that stores `nil` values
      def memoize(hash, key)
        hash.key?(key) ? hash[key] : hash[key] = yield
      end
  end
end
