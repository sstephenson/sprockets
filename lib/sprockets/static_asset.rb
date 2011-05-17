require 'sprockets/asset_pathname'
require 'digest/md5'
require 'time'

module Sprockets
  class StaticAsset
    attr_reader :logical_path, :pathname
    attr_reader :content_type, :mtime, :length, :digest

    def initialize(environment, logical_path, pathname, digest = nil)
      @logical_path = logical_path.to_s
      @pathname     = Pathname.new(pathname)

      asset_pathname = AssetPathname.new(pathname, environment)
      @content_type  = asset_pathname.content_type

      @mtime  = @pathname.mtime
      @length = @pathname.size
      @digest = digest || Digest::MD5.hexdigest(pathname.read)
    end

    def dependencies
      []
    end

    def dependencies?
      false
    end

    def to_a
      [self]
    end

    def body
      to_s
    end

    def stale?
      mtime < pathname.mtime
    rescue Errno::ENOENT
      true
    end

    def each
      yield pathname.read
    end

    def to_path
      pathname.to_s
    end

    def to_s
      pathname.read
    end

    def eql?(other)
      other.class == self.class &&
        other.pathname == self.pathname &&
        other.mtime == self.mtime &&
        other.digest == self.digest
    end
    alias_method :==, :eql?
  end
end
