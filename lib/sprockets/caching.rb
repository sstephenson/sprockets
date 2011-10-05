require 'sprockets/bundled_asset'
require 'sprockets/static_asset'

module Sprockets
  # `Caching` is an internal mixin whose public methods are exposed on
  # the `Environment` and `Index` classes.
  module Caching
    # Return `Asset` instance for serialized `Hash`.
    def asset_from_hash(hash)
      return unless hash.is_a?(Hash)
      case hash['class']
      when 'BundledAsset'
        BundledAsset.from_hash(self, hash)
      when 'StaticAsset'
        StaticAsset.from_hash(self, hash)
      else
        nil
      end
    rescue Exception => e
      logger.debug "Cache for Asset (#{hash['logical_path']}) is stale"
      logger.debug e
      nil
    end

    def cache_hash(key, version)
      if cache.nil?
        yield
      elsif hash = cache_get_hash(key, version)
        hash
      elsif hash = yield
        cache_set_hash(key, version, hash)
        hash
      end
    end

    protected
      # Cache helper method. Takes a `path` argument which maybe a
      # logical path or fully expanded path. The `&block` is passed
      # for finding and building the asset if its not in cache.
      def cache_asset(path)
        # If `cache` is not set, return fast
        if cache.nil?
          yield

        # Check cache for `path`
        elsif (asset = asset_from_hash(cache_get_hash(path.to_s, digest.hexdigest))) && asset.fresh?
          asset

         # Otherwise yield block that slowly finds and builds the asset
        elsif asset = yield
          hash = {}
          asset.encode_with(hash)

          # Save the asset to its path
          cache_set_hash(path.to_s, digest.hexdigest, hash)

          # Since path maybe a logical or full pathname, save the
          # asset its its full path too
          if path.to_s != asset.pathname.to_s
            cache_set_hash(asset.pathname.to_s, digest.hexdigest, hash)
          end

          asset
        end
      end

    private
      # Strips `Environment#root` from key to make the key work
      # consisently across different servers. The key is also hashed
      # so it does not exceed 250 characters.
      def cache_key_for(key)
        File.join('sprockets', digest.hexdigest(key.sub(root, '')))
      end

      def cache_get_hash(key, version)
        hash = cache_get(cache_key_for(key))
        if hash.is_a?(Hash) && version == hash['_version']
          hash
        end
      end

      def cache_set_hash(key, version, hash)
        hash['_version'] = version
        cache_set(cache_key_for(key), hash)
        hash
      end

      # Low level cache getter for `key`. Checks a number of supported
      # cache interfaces.
      def cache_get(key)
        # `Cache#get(key)` for Memcache
        if cache.respond_to?(:get)
          cache.get(key)

        # `Cache#[key]` so `Hash` can be used
        elsif cache.respond_to?(:[])
          cache[key]

        # `Cache#read(key)` for `ActiveSupport::Cache` support
        elsif cache.respond_to?(:read)
          cache.read(key)

        else
          nil
        end
      end

      # Low level cache setter for `key`. Checks a number of supported
      # cache interfaces.
      def cache_set(key, value)
        # `Cache#set(key, value)` for Memcache
        if cache.respond_to?(:set)
          cache.set(key, value)

        # `Cache#[key]=value` so `Hash` can be used
        elsif cache.respond_to?(:[]=)
          cache[key] = value

        # `Cache#write(key, value)` for `ActiveSupport::Cache` support
        elsif cache.respond_to?(:write)
          cache.write(key, value)
        end

        value
      end
  end
end
