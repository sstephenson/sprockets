require 'sprockets/engine_pathname'
require 'sprockets/environment_index'
require 'sprockets/server'
require 'sprockets/utils'
require 'fileutils'
require 'hike'
require 'logger'
require 'pathname'

module Sprockets
  class Environment
    include Server

    attr_accessor :logger, :context

    def initialize(root = ".")
      @trail = Hike::Trail.new(root)
      @trail.extensions.replace Engines::CONCATENATABLE_EXTENSIONS

      @engines = Engines.new(@trail)

      @logger = Logger.new($stderr)
      @logger.level = Logger::FATAL

      @context = Class.new(Context)

      @static_root = nil

      expire_cache
    end

    attr_reader :static_root

    def static_root=(root)
      expire_cache
      @static_root = root
    end

    attr_reader :css_compressor, :js_compressor

    def css_compressor=(compressor)
      expire_cache
      @css_compressor = compressor
    end

    def js_compressor=(compressor)
      expire_cache
      @js_compressor = compressor
    end

    def root
      @trail.root
    end

    class ArrayProxy
      instance_methods.each { |m| undef_method m unless m =~ /(^__|^send$|^object_id$)/ }

      def initialize(target, &callback)
        @target, @callback = target, callback
      end

      def method_missing(sym, *args, &block)
        @callback.call()
        @target.send(sym, *args, &block)
      end
    end

    def paths
      ArrayProxy.new(@trail.paths) { expire_cache }
    end

    attr_reader :engines

    def extensions
      ArrayProxy.new(@trail.extensions) { expire_cache }
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

    def find_asset(logical_path)
      logical_path = Pathname.new(logical_path)

      if asset = find_fresh_asset_from_cache(logical_path)
        asset
      elsif asset = index.find_asset(logical_path)
        @cache[logical_path.to_s] = asset
      end
    end
    alias_method :[], :find_asset

    protected
      def expire_cache
        @cache = {}
      end

      def find_fresh_asset_from_cache(logical_path)
        if asset = @cache[logical_path.to_s]
          if Utils.path_fingerprint(logical_path)
            asset
          elsif asset.stale?
            logger.warn "[Sprockets] #{logical_path} #{asset.digest} stale"
            nil
          else
            logger.info "[Sprockets] #{logical_path} #{asset.digest} fresh"
            asset
          end
        else
          nil
        end
      end
  end
end
