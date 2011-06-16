require 'pathname'

module Sprockets
  class AssetAttributes
    attr_reader :environment, :pathname

    def initialize(environment, path)
      @environment = environment
      @pathname = path.is_a?(Pathname) ? path : Pathname.new(path.to_s)
    end

    def basename_without_extensions
      @pathname.basename(extensions.join)
    end

    def extensions
      @extensions ||= @pathname.basename.to_s.scan(/\.[^.]+/)
    end

    def pretty_path
      @pretty_path ||= @pathname.
        sub(/^#{Regexp.escape(ENV['HOME'] || '')}/, '~').
        sub(/^#{Regexp.escape(environment.root)}\//, '')
    end

    def index_path
      if basename_without_extensions.to_s == 'index'
        pathname.to_s
      else
        basename = "#{basename_without_extensions}/index#{extensions.join}"
        pathname.dirname.to_s == '.' ? basename : pathname.dirname.join(basename).to_s
      end
    end

    def format_extension
      extensions.detect { |ext| @environment.mime_types(ext) }
    end

    def engine_extensions
      exts = extensions

      if offset = extensions.index(format_extension)
        exts = extensions[offset+1..-1]
      end

      exts.select { |ext| @environment.engines(ext) }
    end

    def without_engine_extensions
      engine_extensions.inject(pathname) do |p, ext|
        p.sub(ext, '')
      end
    end

    def engines
      engine_extensions.map { |ext| @environment.engines(ext) }
    end

    def processors
      environment.processors(content_type) + engines.reverse
    end

    def engine_content_type
      engines.reverse.each do |engine|
        if engine.respond_to?(:default_mime_type) && engine.default_mime_type
          return engine.default_mime_type
        end
      end
      nil
    end

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

    def path_fingerprint
      pathname.basename(extensions.join).to_s =~ /-([0-9a-f]{7,40})$/ ? $1 : nil
    end

    def path_with_fingerprint(digest)
      if path_fingerprint
        path.sub($1, digest)
      else
        basename = "#{pathname.basename(extensions.join)}-#{digest}#{extensions.join}"
        pathname.dirname.to_s == '.' ? basename : pathname.dirname.join(basename).to_s
      end
    end
  end
end
