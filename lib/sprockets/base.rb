require 'sprockets/asset'
require 'sprockets/bower'
require 'sprockets/cache'
require 'sprockets/configuration'
require 'sprockets/digest_utils'
require 'sprockets/errors'
require 'sprockets/loader'
require 'sprockets/path_digest_utils'
require 'sprockets/path_dependency_utils'
require 'sprockets/path_utils'
require 'sprockets/resolve'
require 'sprockets/server'

module Sprockets
  # `Base` class for `Environment` and `Cached`.
  class Base
    include PathUtils, PathDependencyUtils, PathDigestUtils, DigestUtils
    include Configuration
    include Server
    include Resolve, Loader
    include Bower

    # Get persistent cache store
    attr_reader :cache

    # Set persistent cache store
    #
    # The cache store must implement a pair of getters and
    # setters. Either `get(key)`/`set(key, value)`,
    # `[key]`/`[key]=value`, `read(key)`/`write(key, value)`.
    def cache=(cache)
      @cache = Cache.new(cache, logger)
    end

    # Return an `Cached`. Must be implemented by the subclass.
    def cached
      raise NotImplementedError
    end
    alias_method :index, :cached

    # Internal: Compute digest for path.
    #
    # path - String filename or directory path.
    #
    # Returns a String digest or nil.
    def file_digest(path)
      if stat = self.stat(path)
        # Caveat: Digests are cached by the path's current mtime. Its possible
        # for a files contents to have changed and its mtime to have been
        # negligently reset thus appearing as if the file hasn't changed on
        # disk. Also, the mtime is only read to the nearest second. Its
        # also possible the file was updated more than once in a given second.
        cache.fetch(['file_digest', path, stat.mtime.to_i]) do
          self.stat_digest(path, stat)
        end
      end
    end

    # Find asset by logical path or expanded path.
    def find_asset(*args)
      uri, _ = resolve(*args)
      if uri
        load(uri)
      end
    end

    def find_all_linked_assets(*args)
      return to_enum(__method__, *args) unless block_given?

      asset = find_asset(*args)
      return unless asset

      yield asset
      stack = asset.links.to_a

      while uri = stack.shift
        yield asset = load(uri)
        stack = asset.links.to_a + stack
      end

      nil
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
  end
end
