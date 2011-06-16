require 'sprockets/base'
require 'sprockets/context'
require 'sprockets/directive_processor'
require 'sprockets/index'

require 'hike'
require 'logger'
require 'pathname'
require 'tilt'

module Sprockets
  class Environment < Base
    def initialize(root = ".")
      @trail = Hike::Trail.new(root)

      self.logger = Logger.new($stderr)
      self.logger.level = Logger::FATAL

      @context_class = Class.new(Context)

      require 'digest/md5'
      @digest_class = ::Digest::MD5
      @digest_key_prefix = ''

      @static_root = nil

      @engines = Sprockets.engines
      @trail.extensions.replace(engine_extensions)

      @mime_types = {}
      @processors = Hash.new { |h, k| h[k] = [] }
      @bundle_processors = Hash.new { |h, k| h[k] = [] }

      register_mime_type 'text/css', '.css'
      register_mime_type 'application/javascript', '.js'

      register_processor 'text/css', DirectiveProcessor
      register_processor 'application/javascript', DirectiveProcessor

      register_bundle_processor 'text/css', CharsetNormalizer

      expire_index!

      yield self if block_given?
    end

    def index
      Index.new(self)
    end

    def find_asset(path, options = {})
      cache_asset(path) { super }
    end

    protected
      def cache_get_asset(path)
        if (asset = @assets[path.to_s]) && !asset.stale?
          asset
        else
          super
        end
      end

      def cache_set_asset(path, asset)
        @assets[path.to_s] = asset
        super
      end

      def expire_index!
        @digest = nil
        @assets = {}
      end
  end
end
