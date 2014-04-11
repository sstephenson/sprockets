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

    # Reverse guess logical path for fully expanded path.
    def logical_path
      if root_path = environment.paths.detect { |path| pathname.to_s["#{path}#{File::Separator}"] }
        path = pathname.relative_path_from(Pathname.new(root_path)).to_s
        path = engine_extensions.inject(path) { |p, ext| p.sub(ext, '') }
        path = "#{path}#{engine_format_extension}" unless format_extension
        path
      else
        raise FileOutsidePaths, "#{pathname} isn't in paths: #{environment.paths.join(', ')}"
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
      extensions.reverse.detect { |ext|
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
          format_content_type ||
            engine_content_type ||
            'application/octet-stream'
        end
      end
    end

    private
      def format_content_type
        format_extension && environment.mime_types(format_extension)
      end

      # Returns implicit engine content type.
      #
      # `.coffee` files carry an implicit `application/javascript`
      # content type.
      def engine_content_type
        engine_extensions.reverse.each do |ext|
          if mime_type = environment.engine_mime_types[ext]
            return mime_type
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
