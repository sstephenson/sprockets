require 'sprockets/concatenation'
require 'sprockets/engine_pathname'
require 'sprockets/errors'

module Sprockets
  class ConcatenatedAsset
    attr_reader :content_type, :format_extension
    attr_reader :mtime, :length, :digest

    def initialize(environment, pathname)
      engine_pathname   = EnginePathname.new(pathname, environment.engines)
      @content_type     = engine_pathname.content_type
      @format_extension = engine_pathname.format_extension

      concatenation = Concatenation.new(environment, pathname)
      concatenation.require(pathname)
      concatenation.post_process!

      @source_paths = concatenation.paths
      @mtime        = concatenation.mtime
      @length       = concatenation.length
      @digest       = concatenation.digest
      @source       = concatenation.to_s
    end

    def each
      yield @source
    end

    def stale?
      @source_paths.any? { |p| mtime < File.mtime(p) }
    rescue Errno::ENOENT
      true
    end

    def to_s
      @source
    end

    def eql?(other)
      other.class == self.class &&
        other.content_type == self.content_type &&
        other.format_extension == self.format_extension &&
        other.source_paths == self.source_paths &&
        other.mtime == self.mtime &&
        other.digest == self.digest
    end
    alias_method :==, :eql?
  end
end
