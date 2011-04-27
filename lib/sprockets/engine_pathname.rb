require 'pathname'
require 'rack/mime'
require 'sprockets/utils'

module Sprockets
  class EnginePathname
    def self.new(path, engines)
      path.is_a?(self) ? path : super(path, engines)
    end

    def initialize(path, engines)
      @pathname = path.is_a?(Pathname) ? path : Pathname.new(path.to_s)
      @engines  = engines
    end

    def basename_without_extensions
      @pathname.basename(extensions.join)
    end

    def extensions
      @extensions ||= @pathname.basename.to_s.scan(/\.[^.]+/)
    end

    def format_extension
      extensions.detect { |ext| lookup_mime_type(ext) }
    end

    def engine_extensions
      exts = extensions

      if offset = extensions.index(format_extension)
        exts = extensions[offset+1..-1]
      end

      exts.select { |ext| @engines[ext] }
    end

    def engines
      engine_extensions.map { |ext| @engines[ext] }
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
      @content_type ||= lookup_mime_type(format_extension) ||
        engine_content_type ||
        'application/octet-stream'
    end

    private
      def lookup_mime_type(ext)
        Rack::Mime.mime_type(ext, nil)
      end
  end
end
