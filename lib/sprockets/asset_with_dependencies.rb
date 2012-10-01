require 'sprockets/asset'
require 'sprockets/utils'

module Sprockets
  # `AssetWithDependencies` is the base class for `ProcessedAsset` and `UnprocessedAsset`.
  class AssetWithDependencies < Asset

    # :dependency_digest is used internally to check equality
    attr_reader :dependency_digest, :source


    # Initialize asset from serialized hash
    def init_with(environment, coder, asset_options = {})
      asset_options[:bundle] = false

      super(environment, coder)

      @source = coder['source']
      @dependency_digest = coder['dependency_digest']

      @required_assets = coder['required_paths'].map { |p|
        p = expand_root_path(p)

        unless environment.paths.detect { |path| p[path] }
          raise UnserializeError, "#{p} isn't in paths"
        end

        p == pathname.to_s ? self : environment.find_asset(p, asset_options)
      }
      @dependency_paths = coder['dependency_paths'].map { |h|
        DependencyFile.new(expand_root_path(h['path']), h['mtime'], h['digest'])
      }
    end

    # Serialize custom attributes.
    def encode_with(coder)
      super

      coder['source'] = source
      coder['dependency_digest'] = dependency_digest

      coder['required_paths'] = required_assets.map { |a|
        relativize_root_path(a.pathname).to_s
      }
      coder['dependency_paths'] = dependency_paths.map { |d|
        { 'path' => relativize_root_path(d.pathname).to_s,
          'mtime' => d.mtime.iso8601,
          'digest' => d.digest }
      }
    end

    # Checks if Asset is stale by comparing the actual mtime and
    # digest to the inmemory model.
    def fresh?(environment)
      # Check freshness of all declared dependencies
      @dependency_paths.all? { |dep| dependency_fresh?(environment, dep) }
    end

    protected
      class DependencyFile < Struct.new(:pathname, :mtime, :digest)
        def initialize(pathname, mtime, digest)
          pathname = Pathname.new(pathname) unless pathname.is_a?(Pathname)
          mtime    = Time.parse(mtime) if mtime.is_a?(String)
          super
        end

        def eql?(other)
          other.is_a?(DependencyFile) &&
            pathname.eql?(other.pathname) &&
            mtime.eql?(other.mtime) &&
            digest.eql?(other.digest)
        end

        def hash
          pathname.to_s.hash
        end
      end

    private
      def build_required_assets(environment, context, asset_options = {})
        required_paths = context._required_paths + [pathname.to_s]
        @required_assets = resolve_dependencies(environment, required_paths, asset_options) -
          resolve_dependencies(environment, context._stubbed_assets.to_a, asset_options)
      end

      def resolve_dependencies(environment, paths, asset_options = {})
        asset_options[:bundle] = false
        assets = []
        cache  = {}

        paths.each do |path|
          if path == self.pathname.to_s
            unless cache[self]
              cache[self] = true
              assets << self
            end
          elsif asset = environment.find_asset(path, asset_options)
            asset.required_assets.each do |asset_dependency|
              unless cache[asset_dependency]
                cache[asset_dependency] = true
                assets << asset_dependency
              end
            end
          end
        end

        assets
      end

      def build_dependency_paths(environment, context, asset_options = {})
        asset_options[:bundle] = false
        dependency_paths = {}

        context._dependency_paths.each do |path|
          dep = DependencyFile.new(path, environment.stat(path).mtime, environment.file_digest(path).hexdigest)
          dependency_paths[dep] = true
        end

        context._dependency_assets.each do |path|
          if path == self.pathname.to_s
            dep = DependencyFile.new(pathname, environment.stat(path).mtime, environment.file_digest(path).hexdigest)
            dependency_paths[dep] = true
          elsif asset = environment.find_asset(path, asset_options)
            asset.dependency_paths.each do |d|
              dependency_paths[d] = true
            end
          end
        end

        @dependency_paths = dependency_paths.keys
      end

      def compute_dependency_digest(environment)
        required_assets.inject(environment.digest) { |digest, asset|
          digest.update asset.digest
        }.hexdigest
      end
  end
end
