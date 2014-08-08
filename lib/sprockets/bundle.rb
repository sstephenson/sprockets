require 'monitor'
require 'set'

module Sprockets
  # Internal: Bundle processor takes a single file asset and prepends all the
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
    LOCK = Monitor.new

    def self.call(input)
      new.call(input)
    end

    def call(input)
      LOCK.synchronize do
        env = input[:environment]
        filename = input[:filename]

        type = input[:content_type]

        assets = Hash.new do |h, path|
          h[path] = env.find_asset(path, bundle: false, accept: type)
        end

        required_paths = expand_required_paths(env, assets, [filename])
        stubbed_paths  = expand_required_paths(env, assets, Array(assets[filename].metadata[:stubbed_paths]))
        required_paths.subtract(stubbed_paths)

        dependency_paths = required_paths.inject(Set.new) do |set, path|
          set.merge(assets[path].metadata[:dependency_paths])
        end

        data = join_assets(required_paths.map { |path| assets[path].to_s })

        # Deprecated: For Asset#to_a
        required_asset_hashes = required_paths.map { |path| assets[path].to_hash }

        { data: data,
          required_asset_hashes: required_asset_hashes,
          dependency_paths: dependency_paths }
      end
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

      def join_assets(ary)
        ary.join
      end
  end

  class StylesheetBundle < Bundle
  end

  class JavascriptBundle < Bundle
    # Internal: Check if data is missing a trailing semicolon.
    #
    # data - String
    #
    # Returns true or false.
    def self.missing_semicolon?(data)
      i = data.size - 1
      while i >= 0
        c = data[i]
        i -= 1
        if c == "\n" || c == " " || c == "\t"
          next
        elsif c != ";"
          return true
        else
          return false
        end
      end
      false
    end

    def join_assets(ary)
      ary.map do |data|
        if self.class.missing_semicolon?(data)
          data + ";\n"
        else
          data
        end
      end.join
    end
  end
end
