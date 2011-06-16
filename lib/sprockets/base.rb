require 'sprockets/asset_attributes'
require 'sprockets/bundled_asset'
require 'sprockets/caching'
require 'sprockets/digest'
require 'sprockets/processing'
require 'sprockets/server'
require 'sprockets/static_asset'
require 'sprockets/static_compilation'
require 'sprockets/trail'
require 'pathname'

module Sprockets
  class Base
    include Digest
    include Caching, Processing, Server, StaticCompilation, Trail

    attr_accessor :logger

    attr_reader :context_class

    attr_reader :cache

    def cache=(cache)
      expire_index!
      @cache = cache
    end

    def index
      raise NotImplementedError
    end

    def entries(pathname)
      trail.entries(pathname)
    end

    def stat(path)
      trail.stat(path)
    end

    def file_digest(path, data = nil)
      if stat = self.stat(path)
        if data
          digest.update(data)
        elsif stat.file?
          digest.file(path)
        elsif stat.directory?
          contents = self.entries(path).join(',')
          digest.update(contents)
        end
      end
    end

    def attributes_for(path)
      AssetAttributes.new(self, path)
    end

    def content_type_of(path)
      attributes_for(path).content_type
    end

    def find_asset(path, options = {})
      pathname = Pathname.new(path)

      if pathname.absolute?
        build_asset(detect_logical_path(path).to_s, pathname, options)
      else
        find_asset_in_static_root(pathname) ||
          find_asset_in_path(pathname, options)
      end
    end

    def [](*args)
      find_asset(*args)
    end

    def build_asset(logical_path, pathname, options)
      pathname = Pathname.new(pathname)

      if processors(content_type_of(pathname)).any?
        BundledAsset.new(self, logical_path, pathname, options)
      else
        StaticAsset.new(self, logical_path, pathname)
      end
    end

    protected
      def expire_index!
        raise NotImplementedError
      end

      def detect_logical_path(filename)
        if root_path = paths.detect { |path| filename.to_s[path] }
          root_pathname = Pathname.new(root_path)
          logical_path  = Pathname.new(filename).relative_path_from(root_pathname)
          attributes_for(logical_path).without_engine_extensions
        end
      end

    private
      def memoize(hash, key)
        hash.key?(key) ? hash[key] : hash[key] = yield
      end
  end
end
