require 'sprockets/asset_pathname'
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

      @mime_types = {}
      @engines = {}
      @formats = Hash.new { |h, k| h[k] = [] }
      @filters = Hash.new { |h, k| h[k] = [] }

      register_format '.css', DirectiveProcessor
      register_format '.js', DirectiveProcessor

      register_engine '.str',    Tilt::StringTemplate
      register_engine '.erb',    Tilt::ERBTemplate
      register_engine '.sass',   Tilt::SassTemplate
      register_engine '.scss',   Tilt::ScssTemplate
      register_engine '.less',   Tilt::LessTemplate
      register_engine '.coffee', Tilt::CoffeeScriptTemplate

      register_filter 'text/css', CharsetNormalizer

      expire_index!
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
      ArrayProxy.new(@trail.paths) { expire_index! }
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

    def find_asset(logical_path)
      logical_path = Pathname.new(logical_path)

      if asset = find_fresh_asset_from_cache(logical_path)
        asset
      elsif asset = index.find_asset(logical_path)
        asset.to_a.each { |a| @cache[a.logical_path.to_s] = a }
        asset
      end
    end
    alias_method :[], :find_asset

    protected
      def expire_index!
        @cache = {}
      end

      def find_fresh_asset_from_cache(logical_path)
        if asset = @cache[logical_path.to_s]
          if path_fingerprint(logical_path)
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
