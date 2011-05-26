require 'sprockets/asset_attributes'
require 'sprockets/bundled_asset'
require 'sprockets/errors'
require 'sprockets/static_asset'
require 'pathname'

module Sprockets
  class EnvironmentIndex
    include Server, Processing, StaticCompilation

    attr_reader :logger, :context_class, :opaque_data

    def initialize(environment, trail, static_root)
      @logger         = environment.logger
      @context_class  = environment.context_class

      @trail   = trail.index
      @assets  = {}
      @entries = {}

      @static_root = static_root ? Pathname.new(static_root) : nil

      @mime_types = environment.mime_types
      @engines    = environment.engines
      @processors = environment.processors
      @bundle_processors = environment.bundle_processors
      @opaque_data = environment.opaque_data
    end

    def root
      @trail.root
    end

    def paths
      @trail.paths
    end

    def extensions
      @trail.extensions
    end

    def index
      self
    end

    def resolve(logical_path, options = {})
      if block_given?
        @trail.find(logical_path.to_s, logical_index_path(logical_path), options) do |path|
          yield Pathname.new(path)
        end
      else
        resolve(logical_path, options) do |pathname|
          return pathname
        end
        raise FileNotFound, "couldn't find file '#{logical_path}'"
      end
    end

    def find_asset(path, options = {})
      options[:_index] ||= self

      pathname = Pathname.new(path)

      if pathname.absolute?
        build_asset(detect_logical_path(path).to_s, pathname, options)
      else
        logical_path = path.to_s.sub(/^\//, '')

        if @assets.key?(logical_path)
          @assets[logical_path]
        else
          @assets[logical_path] = find_asset_in_static_root(pathname) ||
            find_asset_in_path(pathname, options)
        end
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
        raise TypeError, "can't modify immutable index"
      end

      def find_asset_in_path(logical_path, options = {})
        if fingerprint = path_fingerprint(logical_path)
          pathname = resolve(logical_path.to_s.sub("-#{fingerprint}", ''))
        else
          pathname = resolve(logical_path)
        end
      rescue FileNotFound
        nil
      else
        asset = build_asset(logical_path, pathname, options)

        if fingerprint && fingerprint != asset.digest
          logger.error "Nonexistent asset #{logical_path} @ #{fingerprint}"
          asset = nil
        end

        asset
      end

      def build_asset(logical_path, pathname, options)
        if asset = @assets[logical_path.to_s]
          return asset
        end

        pathname = Pathname.new(pathname)

        if processors(content_type_of(pathname)).any?
          asset = BundledAsset.new(self, logical_path, pathname, options)
        else
          asset = StaticAsset.new(self, logical_path, pathname)
        end

        @assets[logical_path.to_s] = asset
      end

    private
      def logical_index_path(logical_path)
        pathname   = Pathname.new(logical_path)
        attributes = attributes_for(logical_path)

        if attributes.basename_without_extensions.to_s == 'index'
          logical_path
        else
          basename = "#{attributes.basename_without_extensions}/index#{attributes.extensions.join}"
          pathname.dirname.to_s == '.' ? basename : pathname.dirname.join(basename).to_s
        end
      end

      def detect_logical_path(filename)
        if root_path = paths.detect { |path| filename.to_s[path] }
          root_pathname = Pathname.new(root_path)
          logical_path  = Pathname.new(filename).relative_path_from(root_pathname)
          path_without_engine_extensions(logical_path)
        end
      end

      def path_without_engine_extensions(pathname)
        attributes_for(pathname).engine_extensions.inject(pathname) do |p, ext|
          p.sub(ext, '')
        end
      end
  end
end
