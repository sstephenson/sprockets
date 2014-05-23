require 'set'

module Sprockets
  # Public: Bundle processor takes a single file asset and prepends all the
  # `:required_paths` to the contents.
  #
  # Uses pipeline metadata:
  #
  #   :required_paths - Ordered Set of asset filenames to prepend
  #   :stubbed_paths  - Set of asset filenames to substract from the
  #                     required path set.
  #
  # Also see DirectiveProcessor.
  class Bundle
    def self.call(input)
      new.call(input)
    end

    def call(input)
      env = input[:environment]
      filename = input[:filename]

      assets = Hash.new do |h, path|
        h[path] = env.find_asset(path, bundle: false)
      end

      required_paths = expand_required_paths(env, assets, [filename])
      stubbed_paths  = expand_required_paths(env, assets, Array(assets[filename].metadata[:stubbed_paths]))
      required_paths.subtract(stubbed_paths)

      dependency_paths = required_paths.inject(Set.new) do |set, path|
        set.merge(assets[path].metadata[:dependency_paths])
      end

      data = required_paths.map { |path| assets[path].to_s }.join

      # Deprecated: For Asset#to_a
      required_asset_hashes = required_paths.map { |path| assets[path].to_hash }

      { data: data,
        required_asset_hashes: required_asset_hashes,
        dependency_paths: dependency_paths }
    end

    private
      def expand_required_paths(env, assets, paths)
        deps, seen = Set.new, Set.new
        stack = paths.reverse

        while path = stack.pop
          if seen.include?(path)
            deps.add(path)
          else
            unless asset = assets[path]
              raise FileNotFound, "could not find #{path}"
            end
            stack.push(path)
            stack.concat(Array(asset.metadata[:required_paths]).reverse)
            seen.add(path)
          end
        end

        deps
      end
  end
end
