require 'sprockets/asset'
require 'sprockets/bower'
require 'sprockets/errors'
require 'sprockets/server'
require 'pathname'

module Sprockets
  # `Base` class for `Environment` and `Cached`.
  class Base
    include PathUtils
    include Paths, Bower, Mime, Processing, Compressing, Engines, Server

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

    # Finds the expanded real path for a given logical path by
    # searching the environment's paths.
    #
    #     resolve("application.js")
    #     # => "/path/to/app/javascripts/application.js.coffee"
    #
    # A `FileNotFound` exception is raised if the file does not exist.
    def resolve(path, options = {})
      if filename = resolve_all(path, options).first
        filename
      else
        if absolute_path?(path.to_s) && !paths_split(self.paths, path)
          raise FileOutsidePaths, "#{path} isn't in paths: #{self.paths.join(', ')}"
        end

        content_type = options[:content_type]
        message = "couldn't find file '#{path}'"
        message << " with content type '#{content_type}'" if content_type
        raise FileNotFound, message
      end
    end

    # Register a new mime type.
    def register_mime_type(mime_type, ext)
      super.tap { expire_cache! }
    end

    # Registers a new Engine `klass` for `ext`.
    def register_engine(ext, klass, options = {})
      super.tap { expire_cache! }
    end

    def register_preprocessor(mime_type, klass, &block)
      super.tap { expire_cache! }
    end

    def unregister_preprocessor(mime_type, klass)
      super.tap { expire_cache! }
    end

    def register_postprocessor(mime_type, klass, &block)
      super.tap { expire_cache! }
    end

    def unregister_postprocessor(mime_type, klass)
      super.tap { expire_cache! }
    end

    def register_bundle_processor(mime_type, klass, &block)
      super.tap { expire_cache! }
    end

    def unregister_bundle_processor(mime_type, klass)
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

    # Find asset by logical path or expanded path.
    def find_asset(path, options = {})
      options[:bundle] = true unless options.key?(:bundle)

      if filename = resolve_all(path.to_s).first
        if options[:if_match]
          asset_hash = build_asset_hash_for_digest(filename, options[:if_match], options[:bundle])
        else
          asset_hash = build_asset_hash(filename, options[:bundle])
        end

        Asset.new(asset_hash) if asset_hash
      end
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

      def build_asset_hash_for_digest(filename, digest, bundle)
        asset_hash = build_asset_hash(filename, bundle)
        if asset_hash[:digest] == digest
          asset_hash
        end
      end

      def build_asset_hash(filename, bundle = true)
        content_type = content_type_of(filename) || 'application/octet-stream'

        attributes = {
          filename: filename,
          logical_path: logical_path_for(filename),
          content_type: content_type
        }

        engine_exts = extensions_for(filename)[:engine_extnames]
        processed_processors = preprocessors(content_type) +
          engine_exts.map { |ext| engines(ext) }.reverse +
          postprocessors(content_type)
        bundled_processors = bundle_processors(content_type)

        if processed_processors.any? || bundled_processors.any?
          processors = bundle ? bundled_processors : processed_processors
          build_processed_asset_hash(attributes, processors)
        else
          build_static_asset_hash(attributes)
        end
      end

      def build_processed_asset_hash(asset, processors)
        filename = asset[:filename]
        encoding = encoding_for_mime_type(asset[:content_type])
        data     = read_unicode_file(filename, encoding)

        processed = process(
          processors,
          filename,
          asset[:logical_path],
          asset[:content_type],
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
