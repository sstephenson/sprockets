require 'sprockets/base'

module Sprockets
  class Index < Base
    def initialize(environment)
      @logger            = environment.logger
      @context_class     = environment.context_class
      @cache             = environment.cache
      @trail             = environment.trail.index
      @static_root       = environment.static_root
      @digest            = environment.digest
      @digest_class      = environment.digest_class
      @digest_key_prefix = environment.digest_key_prefix
      @mime_types        = environment.mime_types
      @engines           = environment.engines
      @processors        = environment.processors
      @bundle_processors = environment.bundle_processors

      # Caches
      @assets  = {}
      @digests = {}
    end

    def index
      self
    end

    def file_digest(pathname, data = nil)
      memoize(@digests, pathname.to_s) { super }
    end

    def find_asset(path, options = {})
      cache_asset(path) { super }
    end

    protected
      def expire_index!
        raise TypeError, "can't modify immutable index"
      end

      def cache_get_asset(logical_path)
        if asset = @assets[logical_path.to_s]
          asset
        else
          super
        end
      end

      def cache_set_asset(logical_path, asset)
        @assets[logical_path.to_s] = asset
        super
      end

      def build_asset(logical_path, pathname, options)
        @assets[logical_path.to_s] ||= super
      end
  end
end
