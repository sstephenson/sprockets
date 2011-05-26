require 'sprockets/asset_attributes'
require 'sprockets/context'
require 'sprockets/directive_processor'
require 'sprockets/environment_index'
require 'hike'
require 'logger'
require 'pathname'
require 'tilt'

module Sprockets
  class Environment
    include Server, Processing, StaticCompilation

    attr_accessor :logger, :context_class

    def initialize(root = ".")
      @trail = Hike::Trail.new(root)

      @logger = Logger.new($stderr)
      @logger.level = Logger::FATAL

      @context_class = Class.new(Context)

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
    end

    def root
      @trail.root
    end

    def paths
      @trail.paths#.dup
    end

    def append_path(path)
      expire_index!
      @trail.paths.push(path)
    end

    def prepend_path(path)
      expire_index!
      @trail.paths.unshift(path)
    end

    def clear_paths
      expire_index!
      @trail.paths.clear
    end

    def extensions
      @trail.extensions.dup
    end

    def precompile(*paths)
      index.precompile(*paths)
    end

    def index
      EnvironmentIndex.new(self, @trail, @static_root)
    end

    def resolve(logical_path, options = {}, &block)
      index.resolve(logical_path, options, &block)
    end

    def find_asset(logical_path, options = {})
      logical_path = Pathname.new(logical_path)
      index = options[:_index] || self.index

      if asset = find_fresh_asset_from_cache(logical_path)
        asset
      elsif asset = index.find_asset(logical_path, options.merge(:_environment => self))
        @cache[logical_path.to_s] = asset
        asset.to_a.each { |a| @cache[a.pathname.to_s] = a }
        asset
      end
    end
    alias_method :[], :find_asset

    def attributes_for(path)
      AssetAttributes.new(self, path)
    end

    def content_type_of(path)
      attributes_for(path).content_type
    end

    protected
      def expire_index!
        @cache = {}
      end

      def find_fresh_asset_from_cache(logical_path)
        if asset = @cache[logical_path.to_s]
          if path_fingerprint(logical_path)
            asset
          elsif asset.stale?
            nil
          else
            asset
          end
        else
          nil
        end
      end
  end
end
