require 'sprockets/dependency'
require 'fileutils'
require 'time'
require 'zlib'

module Sprockets
  class StaticAsset
    attr_reader :environment
    attr_reader :logical_path, :pathname
    attr_reader :content_type, :mtime, :length, :digest

    def self.from_hash(environment, hash)
      asset = allocate
      asset.init_with(environment, hash)
      asset
    end

    def initialize(environment, logical_path, pathname, digest = nil)
      @environment = environment

      @logical_path = logical_path.to_s
      @pathname     = Pathname.new(pathname)
      @content_type = environment.content_type_of(pathname)

      @mtime      = environment.stat(@pathname).mtime
      @length     = environment.stat(@pathname).size
      @digest     = environment.file_digest(pathname).hexdigest
      @dependency = Dependency.new(environment.digest.hexdigest, @pathname.to_s, @mtime, @digest)
    end

    def init_with(environment, coder)
      @environment = environment

      @logical_path = coder['logical_path'].to_s
      @pathname     = Pathname.new(coder['pathname'])
      @content_type = coder['content_type']
      @mtime        = coder['mtime'].is_a?(String) ? Time.parse(coder['mtime']) : coder['mtime']
      @length       = coder['length']
      @digest       = coder['digest']
      @dependency   = Dependency.from_hash(coder['dependency'])
    end

    def encode_with(coder)
      coder['class']        = 'StaticAsset'
      coder['logical_path'] = logical_path
      coder['pathname']     = pathname.to_s
      coder['content_type'] = content_type
      coder['mtime']        = mtime
      coder['digest']       = digest
      coder['length']       = length
      coder['dependency']   = {}
      @dependency.encode_with(coder['dependency'])
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

    def fresh?
      @dependency.fresh?(environment)
    end

    def stale?
      !fresh?
    end

    def each
      yield to_s
    end

    def to_path
      pathname.to_s
    end

    def to_s
      pathname.open('rb') { |f| f.read }
    end

    def inspect
      "#<#{self.class}:0x#{object_id.to_s(16)} " +
        "pathname=#{pathname.to_s.inspect}, " +
        "mtime=#{mtime.inspect}, " +
        "digest=#{digest.inspect}" +
        ">"
    end

    def write_to(filename, options = {})
      options[:compress] ||= File.extname(filename) == '.gz'

      if options[:compress]
        pathname.open('rb') do |rd|
          File.open("#{filename}+", 'wb') do |wr|
            gz = Zlib::GzipWriter.new(wr, Zlib::BEST_COMPRESSION)
            buf = ""
            while rd.read(16384, buf)
              gz.write(buf)
            end
            gz.close
          end
        end
      else
        FileUtils.cp(pathname, "#{filename}+")
      end

      FileUtils.mv("#{filename}+", filename)
      File.utime(mtime, mtime, filename)

      nil
    ensure
      FileUtils.rm("#{filename}+") if File.exist?("#{filename}+")
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
