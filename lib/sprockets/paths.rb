module Sprockets
  module Paths
    # Returns `Environment` root.
    #
    # All relative paths are expanded with root as its base. To be
    # useful set this to your applications root directory. (`Rails.root`)
    def root
      @trail.root.dup
    end

    # Returns an `Array` of path `String`s.
    #
    # These paths will be used for asset logical path lookups.
    #
    # Note that a copy of the `Array` is returned so mutating will
    # have no affect on the environment. See `append_path`,
    # `prepend_path`, and `clear_paths`.
    def paths
      @trail.paths.dup
    end

    # Prepend a `path` to the `paths` list.
    #
    # Paths at the end of the `Array` have the least priority.
    def prepend_path(path)
      @trail.prepend_path(path)
    end

    # Append a `path` to the `paths` list.
    #
    # Paths at the beginning of the `Array` have a higher priority.
    def append_path(path)
      @trail.append_path(path)
    end

    # Clear all paths and start fresh.
    #
    # There is no mechanism for reordering paths, so its best to
    # completely wipe the paths list and reappend them in the order
    # you want.
    def clear_paths
      @trail.paths.dup.each { |path| @trail.remove_path(path) }
    end

    # Returns an `Array` of extensions.
    #
    # These extensions maybe omitted from logical path searches.
    #
    #     # => [".js", ".css", ".coffee", ".sass", ...]
    #
    def extensions
      @trail.extensions.dup
    end

    # Works like `Dir.entries`.
    #
    # Subclasses may cache this method.
    def entries(pathname)
      @trail.entries(pathname)
    end

    # Works like `File.stat`.
    #
    # Subclasses may cache this method.
    def stat(path)
      @trail.stat(path)
    end

    # Recursive stat all the files under a directory.
    #
    # root  - A String or Pathname directory
    # block - Block called for each entry
    #   path - Pathname
    #   stat - File::Stat
    #
    # Returns nothing.
    def recursive_stat(root, &block)
      root = Pathname.new(root) unless root.is_a?(Pathname)

      entries(root).sort.each do |filename|
        path = root.join(filename)
        stat = self.stat(path)
        yield path, stat

        if stat && stat.directory?
          recursive_stat(path, &block)
        end
      end

      nil
    end

    def find_logical_paths(*args, &block)
      return to_enum(__method__, *args) unless block_given?
      filters = args.flatten
      files = {}

      paths.each do |root|
        recursive_stat(root) do |path, stat|
          next unless stat.file?

          if logical_path = logical_path_for_filename(path, filters)
            unless files[logical_path]
              if block.arity == 2
                yield logical_path, path.to_s
              else
                yield logical_path
              end
            end

            files[logical_path] = true
          end
        end
      end
      nil
    end

    protected
      attr_reader :trail

      def logical_path_for_filename(filename, filters)
        logical_path = attributes_for(filename).logical_path.to_s

        if matches_filter(filters, logical_path, filename)
          return logical_path
        end

        # If filename is an index file, retest with alias
        if File.basename(logical_path)[/[^\.]+/, 0] == 'index'
          path = logical_path.sub(/\/index\./, '.')
          if matches_filter(filters, path, filename)
            return path
          end
        end

        nil
      end

      def matches_filter(filters, logical_path, filename)
        return true if filters.empty?

        filters.any? do |filter|
          if filter.is_a?(Regexp)
            filter.match(logical_path)
          elsif filter.respond_to?(:call)
            if filter.arity == 1
              filter.call(logical_path)
            else
              filter.call(logical_path, filename.to_s)
            end
          else
            File.fnmatch(filter.to_s, logical_path)
          end
        end
      end
  end
end
