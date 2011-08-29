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
  # `Base` class for `Environment` and `Index`.
  class Base
    include Digest
    include Caching, Processing, Server, StaticCompilation, Trail

    # Get and set `Logger` instance.
    attr_accessor :logger

    # Get `Context` class.
    #
    # This class maybe mutated and mixed in with custom helpers.
    #
    #     environment.context_class.instance_eval do
    #       include MyHelpers
    #       def asset_url; end
    #     end
    #
    attr_reader :context_class

    # Get persistent cache store
    attr_reader :cache

    # Set persistent cache store
    #
    # The cache store must implement a pair of getters and
    # setters. Either `get(key)`/`set(key, value)`,
    # `[key]`/`[key]=value`, `read(key)`/`write(key, value)`.
    def cache=(cache)
      expire_index!
      @cache = cache
    end

    # Return an `Index`. Must be implemented by the subclass.
    def index
      raise NotImplementedError
    end

    # Works like `Dir.entries`.
    #
    # Subclasses may cache this method.
    def entries(pathname)
      trail.entries(pathname)
    end

    # Works like `File.stat`.
    #
    # Subclasses may cache this method.
    def stat(path)
      trail.stat(path)
    end

    # Read and compute digest of filename.
    #
    # Subclasses may cache this method.
    def file_digest(path, data = nil)
      if stat = self.stat(path)
        # `data` maybe provided
        if data
          digest.update(data)

        # If its a file, digest the contents
        elsif stat.file?
          digest.file(path.to_s)

        # If its a directive, digest the list of filenames
        elsif stat.directory?
          contents = self.entries(path).join(',')
          digest.update(contents)
        end
      end
    end

    # Internal. Return a `AssetAttributes` for `path`.
    def attributes_for(path)
      AssetAttributes.new(self, path)
    end

    # Internal. Return content type of `path`.
    def content_type_of(path)
      attributes_for(path).content_type
    end

    # Find asset by logical path or expanded path.
    def find_asset(path, options = {})
      pathname = Pathname.new(path)

      if pathname.absolute?
        build_asset(attributes_for(pathname).logical_path, pathname, options)
      else
        find_asset_in_path(pathname, options)
      end
    end

    # Preferred `find_asset` shorthand.
    #
    #     environment['application.js']
    #
    def [](*args)
      find_asset(*args)
    end

    def each_file
      return to_enum(__method__) unless block_given?
      paths.each do |base_path|
        Dir["#{base_path}/**/*"].each do |filename|
          yield filename unless File.directory?(filename)
        end
      end
      nil
    end

    def each_logical_path
      return to_enum(__method__) unless block_given?
      files = {}
      each_file do |filename|
        logical_path = attributes_for(filename).logical_path
        yield logical_path unless files[logical_path]
        files[logical_path] = true
      end
      nil
    end

    # Pretty inspect
    def inspect
      "#<#{self.class}:0x#{object_id.to_s(16)} " +
        "root=#{root.to_s.inspect}, " +
        "paths=#{paths.inspect}, " +
        "digest=#{digest.to_s.inspect}" +
        ">"
    end

    protected
      # Clear index after mutating state. Must be implemented by the subclass.
      def expire_index!
        raise NotImplementedError
      end

      def build_asset(logical_path, pathname, options)
        pathname = Pathname.new(pathname)

        return unless stat(pathname)

        # If there are any processors to run on the pathname, use
        # `BundledAsset`. Otherwise use `StaticAsset` and treat is as binary.
        if attributes_for(pathname).processors.any?
          BundledAsset.new(self, logical_path, pathname, options)
        else
          StaticAsset.new(self, logical_path, pathname)
        end
      end
  end
end
