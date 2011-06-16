require 'sprockets/errors'
require 'pathname'

module Sprockets
  module Trail
    def self.included(base)
      base.instance_eval do
        attr_reader :trail
        protected :trail
      end
    end

    def root
      trail.root.dup
    end

    def paths
      trail.paths.dup
    end

    def append_path(path)
      expire_index!
      @trail.paths.push(path)
    end

    def prepend_path(path)
      expire_index!
      @trail.paths.unshift(path)
    end

    def clear_paths
      expire_index!
      @trail.paths.clear
    end

    def extensions
      trail.extensions.dup
    end

    def resolve(logical_path, options = {})
      if block_given?
        trail.find(logical_path.to_s, attributes_for(logical_path).index_path, options) do |path|
          yield Pathname.new(path)
        end
      else
        resolve(logical_path, options) do |pathname|
          return pathname
        end
        raise FileNotFound, "couldn't find file '#{logical_path}'"
      end
    end

    protected
      def compute_digest
        digest = super

        digest << root.to_s
        digest << trail.paths.join(',')

        digest
      end

      def find_asset_in_path(logical_path, options = {})
        if fingerprint = attributes_for(logical_path).path_fingerprint
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
  end
end
