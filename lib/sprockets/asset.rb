require 'time'

module Sprockets
  # `Asset` is the base class for `BundledAsset` and `StaticAsset`.
  class Asset
    # Internal initializer to load `Asset` from serialized `Hash`.
    def self.from_hash(environment, hash)
      asset = allocate
      asset.init_with(environment, hash)
      asset
    end

    # Define base set of attributes to be serialized.
    def self.serialized_attributes
      %w( id logical_path pathname )
    end

    attr_reader :environment
    attr_reader :id, :logical_path, :pathname

    def initialize(environment, logical_path, pathname)
      @environment  = environment
      @logical_path = logical_path.to_s
      @pathname     = Pathname.new(pathname)
      @id           = environment.digest.update(object_id.to_s).to_s
    end

    # Initialize `Asset` from serialized `Hash`.
    def init_with(environment, coder)
      @environment = environment
      @pathname = @mtime = @length = nil

      self.class.serialized_attributes.each do |attr|
        instance_variable_set("@#{attr}", coder[attr].to_s) if coder[attr]
      end

      if @pathname && @pathname.is_a?(String)
        # Expand `$root` placeholder and wrapper string in a `Pathname`
        @pathname = Pathname.new(expand_root_path(@pathname))
      end

      if @mtime && @mtime.is_a?(String)
        # Parse time string
        @mtime = Time.parse(@mtime)
      end

      if @length && @length.is_a?(String)
        # Convert length to an `Integer`
        @length = Integer(@length)
      end
    end

    def path
      if environment.fingerprinting_enabled?
        attributes = environment.attributes_for(logical_path)
        attributes.path_with_fingerprint(digest)
      else
        logical_path
      end
    end

    # Copy serialized attributes to the coder object
    def encode_with(coder)
      coder['class'] = self.class.name.sub(/Sprockets::/, '')

      self.class.serialized_attributes.each do |attr|
        coder[attr] = send(attr).to_s
      end

      coder['pathname'] = relativize_root_path(coder['pathname'])
    end

    # Returns `Content-Type` from pathname.
    def content_type
      @content_type ||= environment.content_type_of(pathname)
    end

    # Get mtime at the time the `Asset` is built.
    def mtime
      @mtime ||= environment.stat(pathname).mtime
    end

    # Get length at the time the `Asset` is built.
    def length
      @length ||= environment.stat(pathname).size
    end

    # Get content digest at the time the `Asset` is built.
    def digest
      @digest ||= environment.file_digest(pathname).hexdigest
    end

    # Return an `Array` of `Asset` files that are declared dependencies.
    def dependencies
      []
    end

    # Expand asset into an `Array` of parts.
    #
    # Appending all of an assets body parts together should give you
    # the asset's contents as a whole.
    #
    # This allows you to link to individual files for debugging
    # purposes.
    def to_a
      [self]
    end

    # Add enumerator to allow `Asset` instances to be used as Rack
    # compatible body objects.
    def each
      yield to_s
    end

    # Checks if Asset is fresh by comparing the actual mtime and
    # digest to the inmemory model.
    #
    # Used to test if cached models need to be rebuilt.
    #
    # Subclass must override `fresh?` or `stale?`.
    def fresh?
      !stale?
    end

    # Checks if Asset is stale by comparing the actual mtime and
    # digest to the inmemory model.
    #
    # Subclass must override `fresh?` or `stale?`.
    def stale?
      !fresh?
    end

    # Pretty inspect
    def inspect
      "#<#{self.class}:0x#{object_id.to_s(16)} " +
        "pathname=#{pathname.to_s.inspect}, " +
        "mtime=#{mtime.inspect}, " +
        "digest=#{digest.inspect}" +
        ">"
    end

    # Assets are equal if they share the same path, mtime and digest.
    def eql?(other)
      other.class == self.class &&
        other.relative_pathname == self.relative_pathname &&
        other.mtime == self.mtime &&
        other.digest == self.digest
    end
    alias_method :==, :eql?

    protected
      # Get pathname with its root stripped.
      def relative_pathname
        Pathname.new(relativize_root_path(pathname))
      end

      # Replace `$root` placeholder with actual environment root.
      def expand_root_path(path)
        environment.attributes_for(path).expand_root
      end

      # Replace actual environment root with `$root` placeholder.
      def relativize_root_path(path)
        environment.attributes_for(path).relativize_root
      end

      # Check if dependency is fresh.
      #
      # `dep` is a `Hash` with `path`, `mtime` and `hexdigest` keys.
      #
      # A `Hash` is used rather than other `Asset` object because we
      # want to test non-asset files and directories.
      def dependency_fresh?(dep = {})
        path, mtime, hexdigest = dep.values_at('path', 'mtime', 'hexdigest')

        stat = environment.stat(path)

        # If path no longer exists, its definitely stale.
        if stat.nil?
          return false
        end

        # Compare dependency mime to the actual mtime. If the
        # dependency mtime is newer than the actual mtime, the file
        # hasn't changed since we created this `Asset` instance.
        #
        # However, if the mtime is newer it doesn't mean the asset is
        # stale. Many deployment environments may recopy or recheckout
        # assets on each deploy. In this case the mtime would be the
        # time of deploy rather than modified time.
        if mtime >= stat.mtime
          return true
        end

        digest = environment.file_digest(path)

        # If the mtime is newer, do a full digest comparsion. Return
        # fresh if the digests match.
        if hexdigest == digest.hexdigest
          return true
        end

        # Otherwise, its stale.
        false
      end
  end
end
