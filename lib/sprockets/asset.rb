require 'fileutils'
require 'pathname'
require 'zlib'

module Sprockets
  class Asset
    attr_reader :logical_path
    attr_reader :content_type

    def initialize(attributes = {})
      @attributes = attributes
      attributes.each do |name, value|
        instance_variable_set("@#{name}", value)
      end
    end

    # Internal: Return all internal instance variables as a hash.
    #
    # Returns a Hash.
    def to_hash
      @attributes
    end

    # Public: Metadata accumulated from pipeline process.
    #
    # The API status of the keys is dependent on the pipeline processors
    # itself. So some values maybe considered public and others internal.
    # See the pipeline proccessor documentation itself.
    #
    # Returns Hash.
    attr_reader :metadata

    # Public: Returns String path of asset.
    attr_reader :filename

    # Deprecated: Use #filename instead.
    #
    # Returns Pathname.
    def pathname
      @pathname ||= Pathname.new(filename)
    end

    # Public: Return logical path with digest spliced in.
    #
    #   "foo/bar-37b51d194a7513e45b56f6524f2d51f2.js"
    #
    # Returns String.
    def digest_path
      logical_path.sub(/\.(\w+)$/) { |ext| "-#{digest}#{ext}" }
    end

    # Deprecated: Expand asset into an `Array` of parts.
    #
    # Appending all of an assets body parts together should give you
    # the asset's contents as a whole.
    #
    # This allows you to link to individual files for debugging
    # purposes.
    #
    # Use Asset#source_paths instead. Keeping a full copy of the bundle's
    # processed assets in memory (and in cache) is expensive and redundant. The
    # common use case is to relink to the assets anyway. #source_paths provides
    # that reference.
    #
    # Returns Array of Assets.
    def to_a
      if metadata.key?(:required_asset_hashes)
        metadata[:required_asset_hashes].map do |hash|
          Asset.new(hash)
        end
      else
        [self]
      end
    end

    def source_paths
      to_a.map(&:digest_path)
    end

    # Public: Return `String` of concatenated source.
    #
    # Returns String.
    def source
      if defined? @source
        @source
      else
        # File is read everytime to avoid memory bloat of large binary files
        File.open(filename, 'rb') { |f| f.read }
      end
    end

    # Public: Alias for #source.
    #
    # Returns String.
    def to_s
      source
    end

    # Public: Returns Integer length of source.
    attr_reader :length
    alias_method :bytesize, :length

    # Public: Returns Time of the last time the source was modified.
    #
    # Time resolution is normalized to the nearest second.
    #
    # Returns Time.
    def mtime
      Time.at(@mtime.to_i)
    end

    # Public: Returns String hexdigest of source.
    attr_reader :digest

    # Pubic: ETag String of Asset.
    alias_method :etag, :digest

    # Public: Add enumerator to allow `Asset` instances to be used as Rack
    # compatible body objects.
    #
    # block
    #   part - String body chunk
    #
    # Returns nothing.
    def each
      yield to_s
    end

    # Public: Save asset to disk.
    #
    # filename - String target
    # options  - Hash
    #   compress - Boolean to write out .gz file
    #
    # Returns nothing.
    def write_to(filename, options = {})
      # Gzip contents if filename has '.gz'
      options[:compress] ||= File.extname(filename) == '.gz'

      FileUtils.mkdir_p File.dirname(filename)

      PathUtils.atomic_write(filename) do |f|
        if options[:compress]
          # Run contents through `Zlib`
          gz = Zlib::GzipWriter.new(f, Zlib::BEST_COMPRESSION)
          gz.mtime = mtime.to_i
          gz.write to_s
          gz.close
        else
          # Write out as is
          f.write to_s
        end
      end

      # Set mtime correctly
      File.utime(mtime, mtime, filename)

      nil
    end

    # Public: Pretty inspect
    #
    # Returns String.
    def inspect
      "#<#{self.class}:0x#{object_id.to_s(16)} " +
        "filename=#{filename.inspect}, " +
        "mtime=#{mtime.inspect}, " +
        "digest=#{digest.inspect}" +
        ">"
    end

    # Public: Implements Object#hash so Assets can be used as a Hash key or
    # in a Set.
    #
    # Returns Integer hash of digest.
    def hash
      digest.hash
    end

    # Public: Compare assets.
    #
    # Assets are equal if they share the same path, mtime and digest.
    #
    # Returns true or false.
    def eql?(other)
      other.class == self.class &&
        other.filename == self.filename &&
        other.mtime.to_i == self.mtime.to_i &&
        other.digest == self.digest
    end
    alias_method :==, :eql?
  end
end
