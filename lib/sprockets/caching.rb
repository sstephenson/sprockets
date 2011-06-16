require 'sprockets/bundled_asset'
require 'sprockets/static_asset'

module Sprockets
  module Caching
    def asset_from_hash(hash)
      case hash['class']
      when 'BundledAsset'
        Sprockets::BundledAsset.from_hash(self, hash)
      when 'StaticAsset'
        Sprockets::StaticAsset.from_hash(self, hash)
      else
        nil
      end
    end

    private
      def cache_get(key)
        return unless cache

        if cache.respond_to?(:get)
          cache.get(key)
        elsif cache.respond_to?(:[])
          cache[key]
        elsif cache.respond_to?(:read)
          cache.read(key)
        else
          nil
        end
      end

      def cache_set(key, value)
        return unless cache

        if cache.respond_to?(:set)
          cache.set(key, value)
        elsif cache.respond_to?(:[]=)
          cache[key] = value
        elsif cache.respond_to?(:write)
          cache.write(key, value)
        end

        value
      end

      def cache_get_asset(logical_path)
        hash = cache_get(strip_root(logical_path))

        if hash.is_a?(Hash)
          asset = asset_from_hash(hash)

          if !asset.stale?
            asset
          end
        else
          nil
        end
      end

      def cache_set_asset(logical_path, asset)
        hash = {}
        asset.encode_with(hash)
        cache_set(strip_root(logical_path), hash)
        asset
      end

      def cache_asset(logical_path)
        if asset = cache_get_asset(logical_path)
          asset
        elsif asset = yield
          cache_set_asset(logical_path.to_s, asset)
          if logical_path.to_s != asset.pathname.to_s
            cache_set_asset(asset.pathname.to_s, asset)
          end
          asset
        end
      end

      def strip_root(path)
        path.sub(/^#{Regexp.escape(root)}\//, '')
      end
  end
end
