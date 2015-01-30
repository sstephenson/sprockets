require 'set'
require 'sprockets/http_utils'
require 'sprockets/path_dependency_utils'
require 'sprockets/uri_utils'

module Sprockets
  module Resolve
    include HTTPUtils, PathDependencyUtils, URIUtils

    # Public: Find Asset URI for given a logical path by searching the
    # environment's load paths.
    #
    #     resolve("application.js")
    #     # => "file:///path/to/app/javascripts/application.js?type=application/javascript"
    #
    # An accept content type can be given if the logical path doesn't have a
    # format extension.
    #
    #     resolve("application", accept: "application/javascript")
    #     # => "file:///path/to/app/javascripts/application.coffee?type=application/javascript"
    #
    # The String Asset URI is returned or nil if no results are found.
    def resolve(path, options = {})
      path = path.to_s
      paths = options[:load_paths] || self.paths
      accept = options[:accept]
      skip_bundle = options.key?(:bundle) ? !options[:bundle] : false

      if valid_asset_uri?(path)
        resolve_asset_uri(path)
      elsif absolute_path?(path)
        resolve_absolute_path(paths, path, accept, skip_bundle)
      elsif relative_path?(path)
        resolve_relative_path(paths, path, options[:base_path], accept, skip_bundle)
      else
        resolve_logical_path(paths, path, accept, skip_bundle)
      end
    end

    # Public: Same as resolve() but raises a FileNotFound exception instead of
    # nil if no assets are found.
    def resolve!(path, options = {})
      uri, deps = resolve(path, options)

      unless uri
        message = "couldn't find file '#{path}'"
        message << " with type '#{options[:accept]}'" if options[:accept]
        raise FileNotFound, message
      end

      return uri, deps
    end

    protected
      def resolve_asset_uri(uri)
        filename, _ = parse_asset_uri(uri)
        return uri, Set.new([build_file_digest_uri(filename)])
      end

      def resolve_absolute_path(paths, filename, accept, skip_bundle)
        deps = Set.new
        filename = File.expand_path(filename)

        # Ensure path is under load paths
        return nil, deps unless paths_split(paths, filename)

        mime_type = parse_path_extnames(filename)[1]
        type = resolve_transform_type(mime_type, accept)
        return nil, deps if accept && !type

        return nil, deps unless file?(filename)

        uri = build_asset_uri(filename, type: type, skip_bundle: skip_bundle)
        deps << build_file_digest_uri(filename)
        return uri, deps
      end

      def resolve_relative_path(paths, path, dirname, accept, skip_bundle)
        filename = File.expand_path(path, dirname)
        load_path, _ = paths_split(paths, dirname)
        if load_path && logical_path = split_subpath(load_path, filename)
          resolve_logical_path([load_path], logical_path, accept, skip_bundle)
        else
          [nil, Set.new]
        end
      end

      def resolve_logical_path(paths, logical_path, accept, skip_bundle)
        logical_name, mime_type, _ = parse_path_extnames(logical_path)
        parsed_accept = parse_accept_options(mime_type, accept)
        transformed_accepts = expand_transform_accepts(parsed_accept)
        filename, mime_type, deps = resolve_under_paths(paths, logical_name, transformed_accepts)

        if filename
          deps << build_file_digest_uri(filename)
          type = resolve_transform_type(mime_type, parsed_accept)
          uri = build_asset_uri(filename, type: type, skip_bundle: skip_bundle)
          return uri, deps
        else
          return nil, deps
        end
      end

      def resolve_under_paths(paths, logical_name, accepts)
        all_deps = Set.new
        return nil, nil, all_deps if accepts.empty?

        logical_basename = File.basename(logical_name)
        paths.each do |load_path|
          candidates, deps = path_matches(load_path, logical_name, logical_basename)
          all_deps.merge(deps)
          candidate = find_best_q_match(accepts, candidates) do |c, matcher|
            match_mime_type?(c[1] || "application/octet-stream", matcher)
          end
          return candidate + [all_deps] if candidate
        end

        return nil, nil, all_deps
      end

      def parse_accept_options(mime_type, types)
        accepts = []
        accepts += parse_q_values(types) if types

        if mime_type
          if accepts.empty? || accepts.any? { |accept, _| match_mime_type?(mime_type, accept) }
            accepts = [[mime_type, 1.0]]
          else
            return []
          end
        end

        if accepts.empty?
          accepts << ['*/*', 1.0]
        end

        accepts
      end

      def normalize_logical_path(path)
        dirname, basename = File.split(path)
        path = dirname if basename == 'index'
        path
      end

      def path_matches(load_path, logical_name, logical_basename)
        candidates, deps = [], Set.new
        dirname = File.dirname(File.join(load_path, logical_name))

        result = dirname_matches(dirname, logical_basename)
        candidates.concat(result[0])
        deps.merge(result[1])

        result = resolve_alternates(load_path, logical_name)
        result[0].each do |fn|
          candidates << [fn, parse_path_extnames(fn)[1]]
        end
        deps.merge(result[1])

        result = dirname_matches(File.join(load_path, logical_name), "index")
        candidates.concat(result[0])
        deps.merge(result[1])

        return candidates.select { |fn, _| file?(fn) }, deps
      end

      def dirname_matches(dirname, basename)
        candidates = []
        entries, deps = self.entries_with_dependencies(dirname)
        entries.each do |entry|
          name, type, _ = parse_path_extnames(entry)
          if basename == name
            candidates << [File.join(dirname, entry), type]
          end
        end
        return candidates, deps
      end

      def resolve_alternates(load_path, logical_name)
        return [], Set.new
      end

      # Internal: Returns the name, mime type and `Array` of engine extensions.
      #
      #     "foo.coffee.erb"
      #     # => ["foo", "application/javascript", [".coffee", ".erb"]]
      #
      def parse_path_extnames(path)
        extname, value = match_path_extname(path, config[:_extnames])
        if extname
          name = path[0...-extname.length]
          return name, value[:type], value[:engines]
        else
          return path, nil, []
        end
      end
  end
end
