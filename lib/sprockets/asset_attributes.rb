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

    def engines
      engine_extensions.map { |ext| @environment.engines(ext) }
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
  end
end
