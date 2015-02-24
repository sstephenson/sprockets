require 'json'
require 'securerandom'
require 'time'

module Sprockets
  # The Manifest logs the contents of assets compiled to a single directory. It
  # records basic attributes about the asset for fast lookup without having to
  # compile. A pointer from each logical path indicates which fingerprinted
  # asset is the current one.
  #
  # The JSON is part of the public API and should be considered stable. This
  # should make it easy to read from other programming languages and processes
  # that don't have sprockets loaded. See `#assets` and `#files` for more
  # infomation about the structure.
  class Manifest
    attr_reader :environment

    # Create new Manifest associated with an `environment`. `filename` is a full
    # path to the manifest json file. The file may or may not already exist. The
    # dirname of the `filename` will be used to write compiled assets to.
    # Otherwise, if the path is a directory, the filename will default a random
    # "manifest-123.json" file in that directory.
    #
    #   Manifest.new(environment, "./public/assets/manifest.json")
    #
    def initialize(*args)
      if args.first.is_a?(Base) || args.first.nil?
        @environment = args.shift
      end

      @directory, @filename = args[0], args[1]

      # Expand paths
      @directory = File.expand_path(@directory) if @directory
      @filename  = File.expand_path(@filename) if @filename

      # If filename is given as the second arg
      if @directory && File.extname(@directory) != ""
        @directory, @filename = nil, @directory
      end

      # Default dir to the directory of the filename
      @directory ||= File.dirname(@filename) if @filename

      # If directory is given w/o filename, pick a random manifest.json location
      if @directory && @filename.nil?
        # Find the first manifest.json in the directory
        filenames = Dir[File.join(@directory, "manifest*.json")]
        if filenames.any?
          @filename = filenames.first
        else
          @filename = File.join(@directory, "manifest-#{SecureRandom.hex(16)}.json")
        end
      end

      unless @directory && @filename
        raise ArgumentError, "manifest requires output filename"
      end

      data = {}

      begin
        if File.exist?(@filename)
          data = json_decode(File.read(@filename))
        end
      rescue JSON::ParserError => e
        logger.error "#{@filename} is invalid: #{e.class} #{e.message}"
      end

      @data = data
    end

    # Returns String path to manifest.json file.
    attr_reader :filename
    alias_method :path, :filename

    attr_reader :directory
    alias_method :dir, :directory

    # Returns internal assets mapping. Keys are logical paths which
    # map to the latest fingerprinted filename.
    #
    #   Logical path (String): Fingerprint path (String)
    #
    #   { "application.js" => "application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js",
    #     "jquery.js"      => "jquery-ae0908555a245f8266f77df5a8edca2e.js" }
    #
    def assets
      @data['assets'] ||= {}
    end

    # Returns internal file directory listing. Keys are filenames
    # which map to an attributes array.
    #
    #   Fingerprint path (String):
    #     logical_path: Logical path (String)
    #     mtime: ISO8601 mtime (String)
    #     digest: Base64 hex digest (String)
    #
    #  { "application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js" =>
    #      { 'logical_path' => "application.js",
    #        'mtime' => "2011-12-13T21:47:08-06:00",
    #        'digest' => "2e8e9a7c6b0aafa0c9bdeec90ea30213" } }
    #
    def files
      @data['files'] ||= {}
    end

    # Public: Find all assets matching pattern set in environment.
    #
    # Returns Enumerator of Assets.
    def find(*args)
      unless environment
        raise Error, "manifest requires environment for compilation"
      end

      return to_enum(__method__, *args) unless block_given?

      environment = self.environment.cached
      args.flatten.each do |path|
        environment.find_all_linked_assets(path) do |asset|
          yield asset
        end
      end

      nil
    end

    # Compile and write asset to directory. The asset is written to a
    # fingerprinted filename like
    # `application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js`. An entry is
    # also inserted into the manifest file.
    #
    #   compile("application.js")
    #
    def compile(*args)
      unless environment
        raise Error, "manifest requires environment for compilation"
      end

      filenames = []

      find(*args) do |asset|
        files[asset.digest_path] = {
          'logical_path' => asset.logical_path,
          'mtime'        => Time.now.iso8601,
          'size'         => asset.bytesize,
          'digest'       => asset.hexdigest,
          'integrity'    => asset.integrity
        }
        assets[asset.logical_path] = asset.digest_path

        target = File.join(dir, asset.digest_path)

        if File.exist?(target)
          logger.debug "Skipping #{target}, already exists"
        else
          logger.info "Writing #{target}"
          asset.write_to target
        end

        filenames << asset.filename
      end
      save

      filenames
    end

    # Removes file from directory and from manifest. `filename` must
    # be the name with any directory path.
    #
    #   manifest.remove("application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js")
    #
    def remove(filename)
      path = File.join(dir, filename)
      logical_path = files[filename]['logical_path']

      if assets[logical_path] == filename
        assets.delete(logical_path)
      end

      files.delete(filename)
      FileUtils.rm(path) if File.exist?(path)

      save

      logger.info "Removed #{filename}"

      nil
    end

    # Cleanup old assets in the compile directory. By default it will
    # keep the latest version, 2 backups and any created within the past hour.
    #
    # Examples
    #
    #   To force only 1 backup to be kept, set count=1 and age=0.
    #
    #   To only keep files created within the last 10 minutes, set count=0 and
    #   age=600.
    #
    def clean(count = 2, age = 3600)
      asset_versions = files.group_by { |_, attrs| attrs['logical_path'] }

      asset_versions.each do |logical_path, versions|
        current = assets[logical_path]

        versions.reject { |path, _|
          path == current
        }.sort_by { |_, attrs|
          # Sort by timestamp
          Time.parse(attrs['mtime'])
        }.reverse.each_with_index.drop_while { |(_, attrs), index|
          age = [0, Time.now - Time.parse(attrs['mtime'])].max
          # Keep if under age or within the count limit
          age < age || index < count
        }.each { |(path, _), _|
           # Remove old assets
          remove(path)
        }
      end
    end

    # Wipe directive
    def clobber
      FileUtils.rm_r(directory) if File.exist?(directory)
      logger.info "Removed #{directory}"
      nil
    end

    protected
      # Persist manfiest back to FS
      def save
        data = json_encode(@data)
        FileUtils.mkdir_p File.dirname(filename)
        PathUtils.atomic_write(filename) do |f|
          f.write(data)
        end
      end

    private
      def json_decode(obj)
        JSON.parse(obj, create_additions: false)
      end

      def json_encode(obj)
        JSON.generate(obj)
      end

      def logger
        if environment
          environment.logger
        else
          logger = Logger.new($stderr)
          logger.level = Logger::FATAL
          logger
        end
      end
  end
end
