require 'pathname'

module Sprockets
  # `AssetAttributes` is a wrapper similar to `Pathname` that provides
  # some helper accessors.
  #
  # These methods should be considered internalish.
  class AssetAttributes
    attr_reader :environment, :pathname

    def initialize(environment, path)
      @environment = environment
      @pathname = path.is_a?(Pathname) ? path : Pathname.new(path.to_s)
    end

    # Replaces `$root` placeholder with actual environment root.
    def expand_root
      pathname.to_s.sub(/^\$root/, environment.root)
    end

    # Replaces environment root with `$root` placeholder.
    def relativize_root
      pathname.to_s.sub(/^#{Regexp.escape(environment.root)}/, '$root')
    end

    # Returns paths search the load path for.
    def search_paths
      paths = [pathname.to_s]

      if pathname.basename(extensions.join).to_s != 'index'
        path_without_extensions = extensions.inject(pathname) { |p, ext| p.sub(ext, '') }
        index_path = path_without_extensions.join("index#{extensions.join}").to_s
        paths << index_path
      end

      paths
    end

    # Reverse guess logical path for fully expanded path.
    #
    # This has some known issues. For an example if a file is
    # shaddowed in the path, but is required relatively, its logical
    # path will be incorrect.
    def logical_path
      raise ArgumentError unless pathname.absolute?

      if root_path = environment.paths.detect { |path| pathname.to_s[path] }
        path = pathname.relative_path_from(Pathname.new(root_path)).to_s
        path = engine_extensions.inject(path) { |p, ext| p.sub(ext, '') }
        path = "#{path}#{engine_format_extension}" unless format_extension
        path
      else
        raise Error, "#{pathname} isn't in paths: #{environment.paths.join(', ')}"
      end
    end

    # Returns `Array` of extension `String`s.
    #
    #     "foo.js.coffee"
    #     # => [".js", ".coffee"]
    #
    def extensions
      @extensions ||= @pathname.basename.to_s.scan(/\.[^.]+/)
    end

    # Returns the format extension.
    #
    #     "foo.js.coffee"
    #     # => ".js"
    #
    def format_extension
      extensions.detect { |ext|
        @environment.mime_types(ext) && !@environment.engines(ext)
      }
    end

    # Returns an `Array` of engine extensions.
    #
    #     "foo.js.coffee.erb"
    #     # => [".coffee", ".erb"]
    #
    def engine_extensions
      exts = extensions

      if offset = extensions.index(format_extension)
        exts = extensions[offset+1..-1]
      end

      exts.select { |ext| @environment.engines(ext) }
    end

    # Returns engine classes.
    def engines
      engine_extensions.map { |ext| @environment.engines(ext) }
    end

    # Returns all processors to run on the path.
    def processors
      environment.preprocessors(content_type) +
        engines.reverse +
        environment.postprocessors(content_type)
    end

    # Returns the content type for the pathname. Falls back to `application/octet-stream`.
    def content_type
      @content_type ||= begin
        if format_extension.nil?
          engine_content_type || 'application/octet-stream'
        else
          @environment.mime_types(format_extension) ||
            engine_content_type ||
            'application/octet-stream'
        end
      end
    end

    # Gets digest fingerprint.
    #
    #     "foo-0aa2105d29558f3eb790d411d7d8fb66.js"
    #     # => "0aa2105d29558f3eb790d411d7d8fb66"
    #
    def path_fingerprint
      pathname.basename(extensions.join).to_s =~ /-([0-9a-f]{7,40})$/ ? $1 : nil
    end

    # Injects digest fingerprint into path.
    #
    #     "foo.js"
    #     # => "foo-0aa2105d29558f3eb790d411d7d8fb66.js"
    #
    def path_with_fingerprint(digest)
      if old_digest = path_fingerprint
        pathname.sub(old_digest, digest).to_s
      else
        pathname.to_s.sub(/\.(\w+)$/) { |ext| "-#{digest}#{ext}" }
      end
    end

    private
      # Returns implicit engine content type.
      #
      # `.coffee` files carry an implicit `application/javascript`
      # content type.
      def engine_content_type
        engines.reverse.each do |engine|
          if engine.respond_to?(:default_mime_type) && engine.default_mime_type
            return engine.default_mime_type
          end
        end
        nil
      end

      def engine_format_extension
        if content_type = engine_content_type
          environment.extension_for_mime_type(content_type)
        end
      end
  end
end
