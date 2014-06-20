require 'sprockets/asset'
require 'sprockets/bower'
require 'sprockets/errors'
require 'sprockets/server'
require 'pathname'

module Sprockets
  # `Base` class for `Environment` and `Cached`.
  class Base
    include PathUtils
    include Paths, Mime, Processing, Compressing, Engines, Server
    include Bower

    # Returns a `Digest` implementation class.
    #
    # Defaults to `Digest::SHA1`.
    attr_reader :digest_class

    # Assign a `Digest` implementation class. This maybe any Ruby
    # `Digest::` implementation such as `Digest::SHA1` or
    # `Digest::MD5`.
    #
    #     environment.digest_class = Digest::MD5
    #
    def digest_class=(klass)
      expire_cache!
      @digest_class = klass
    end

    # The `Environment#version` is a custom value used for manually
    # expiring all asset caches.
    #
    # Sprockets is able to track most file and directory changes and
    # will take care of expiring the cache for you. However, its
    # impossible to know when any custom helpers change that you mix
    # into the `Context`.
    #
    # It would be wise to increment this value anytime you make a
    # configuration change to the `Environment` object.
    attr_reader :version

    # Assign an environment version.
    #
    #     environment.version = '2.0'
    #
    def version=(version)
      expire_cache!
      @version = version
    end

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
      expire_cache!
      @cache = Cache.new(cache, logger)
    end

    def prepend_path(path)
      # Overrides the global behavior to expire the cache
      expire_cache!
      super
    end

    def append_path(path)
      # Overrides the global behavior to expire the cache
      expire_cache!
      super
    end

    def clear_paths
      # Overrides the global behavior to expire the cache
      expire_cache!
      super
    end

    def register_mime_type(*args)
      super.tap { expire_cache! }
    end

    def register_engine(*args)
      super.tap { expire_cache! }
    end

    def register_preprocessor(*args)
      super.tap { expire_cache! }
    end

    def unregister_preprocessor(*args)
      super.tap { expire_cache! }
    end

    def register_postprocessor(*args)
      super.tap { expire_cache! }
    end

    def unregister_postprocessor(*args)
      super.tap { expire_cache! }
    end

    def register_bundle_processor(*args)
      super.tap { expire_cache! }
    end

    def unregister_bundle_processor(*args)
      super.tap { expire_cache! }
    end

    # Return an `Cached`. Must be implemented by the subclass.
    def cached
      raise NotImplementedError
    end
    alias_method :index, :cached

    # Internal: Compute hexdigest for path.
    #
    # path - String filename or directory path.
    #
    # Returns a String SHA1 hexdigest or nil.
    def file_hexdigest(path)
      if stat = self.stat(path)
        # Caveat: Digests are cached by the path's current mtime. Its possible
        # for a files contents to have changed and its mtime to have been
        # negligently reset thus appearing as if the file hasn't changed on
        # disk. Also, the mtime is only read to the nearest second. Its
        # also possible the file was updated more than once in a given second.
        cache.fetch(['file_hexdigest', path, stat.mtime.to_i]) do
          if stat.directory?
            # If its a directive, digest the list of filenames
            Digest::SHA1.hexdigest(self.entries(path).join(','))
          elsif stat.file?
            # If its a file, digest the contents
            Digest::SHA1.file(path.to_s).hexdigest
          end
        end
      end
    end

    # Internal: Compute hexdigest for a set of paths.
    #
    # paths - Array of filename or directory paths.
    #
    # Returns a String SHA1 hexdigest.
    def dependencies_hexdigest(paths)
      digest = Digest::SHA1.new
      paths.each { |path| digest.update(file_hexdigest(path).to_s) }
      digest.hexdigest
    end

    # Experimental: Check if environment has asset.
    #
    # TODO: Finalize API.
    #
    # Acts similar to `find_asset(path) ? true : false` but does not build the
    # entire asset.
    #
    # Returns true or false.
    def has_asset?(filename, options = {})
      return false unless file?(filename)

      accepts = (options[:accept] || '*/*').split(/\s*,\s*/)

      # TODO: Review performance
      extname = parse_path_extnames(filename)[1]
      mime_type = mime_type_for_extname(extname)
      accepts.any? { |accept| match_mime_type?(mime_type, accept) }
    end

    # Find asset by logical path or expanded path.
    def find_asset(path, options = {})
      path = path.to_s
      options[:bundle] = true unless options.key?(:bundle)

      if absolute_path?(path)
        filename = path
        return nil unless file?(filename)
      else
        filename = resolve_all(path, accept: options[:accept]).first
      end

      asset_hash = build_asset_hash(filename, options[:bundle]) if filename
      Asset.new(asset_hash) if asset_hash
    end

    # Preferred `find_asset` shorthand.
    #
    #     environment['application.js']
    #
    def [](*args)
      find_asset(*args)
    end

    # Pretty inspect
    def inspect
      "#<#{self.class}:0x#{object_id.to_s(16)} " +
        "root=#{root.to_s.inspect}, " +
        "paths=#{paths.inspect}>"
    end

    protected
      # Clear cached environment after mutating state. Must be implemented by
      # the subclass.
      def expire_cache!
        raise NotImplementedError
      end

      def build_asset_hash(filename, bundle = true)
        load_path, logical_path = paths_split(self.paths, filename)
        unless load_path
          raise FileOutsidePaths, "#{load_path} isn't in paths: #{self.paths.join(', ')}"
        end

        logical_path, extname, engine_extnames = parse_path_extnames(logical_path)
        logical_path = normalize_logical_path(logical_path, extname)

        asset = {
          load_path: load_path,
          filename: filename,
          logical_path: logical_path,
          content_type: mime_type_for_extname(extname)
        }

        processed_processors = unwrap_preprocessors(asset[:content_type]) +
          unwrap_engines(engine_extnames).reverse +
          unwrap_postprocessors(asset[:content_type])
        bundled_processors = unwrap_bundle_processors(asset[:content_type])

        if processed_processors.any? || bundled_processors.any?
          processors = bundle ? bundled_processors : processed_processors
          # processors
          build_processed_asset_hash(asset, processors)
        else
          build_static_asset_hash(asset)
        end
      end

      def build_processed_asset_hash(asset, processors)
        filename = asset[:filename]

        data = File.open(filename, 'rb') { |f| f.read }

        content_type = asset[:content_type]
        mime_type = mime_types[content_type]
        if mime_type && mime_type[:charset]
          data = mime_type[:charset].call(data).encode(Encoding::UTF_8)
        end

        processed = process(
          processors,
          filename,
          asset[:load_path],
          asset[:logical_path],
          content_type,
          data
        )

        # Ensure originally read file is marked as a dependency
        processed[:metadata][:dependency_paths] = Set.new(processed[:metadata][:dependency_paths]).merge([filename])

        asset.merge(processed).merge({
          mtime: processed[:metadata][:dependency_paths].map { |path| stat(path).mtime }.max.to_i,
          metadata: processed[:metadata].merge(
            dependency_digest: dependencies_hexdigest(processed[:metadata][:dependency_paths])
          )
        })
      end

      def build_static_asset_hash(asset)
        stat = self.stat(asset[:filename])
        asset.merge({
          encoding: Encoding::BINARY,
          length: stat.size,
          mtime: stat.mtime.to_i,
          digest: digest_class.file(asset[:filename]).hexdigest,
          metadata: {
            dependency_paths: Set.new([asset[:filename]]),
            dependency_digest: dependencies_hexdigest([asset[:filename]]),
          }
        })
      end
  end
end
