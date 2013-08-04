require 'multi_json'
require 'securerandom'
require 'time'

module Sprockets
  # The Manifest logs the contents of assets compiled to a single
  # directory. It records basic attributes about the asset for fast
  # lookup without having to compile. A pointer from each logical path
  # indicates with fingerprinted asset is the current one.
  #
  # The JSON is part of the public API and should be considered
  # stable. This should make it easy to read from other programming
  # languages and processes that don't have sprockets loaded. See
  # `#assets` and `#files` for more infomation about the structure.
  class Manifest
    attr_reader :environment, :path, :dir

    # Create new Manifest associated with an `environment`. `path` is
    # a full path to the manifest json file. The file may or may not
    # already exist. The dirname of the `path` will be used to write
    # compiled assets to. Otherwise, if the path is a directory, the
    # filename will default a random "manifest-123.json" file in that
    # directory.
    #
    #   Manifest.new(environment, "./public/assets/manifest.json")
    #
    def initialize(*args)
      if args.first.is_a?(Base) || args.first.nil?
        @environment = args.shift
      end

      @dir, @path = args[0], args[1]

      # Expand paths
      @dir  = File.expand_path(@dir) if @dir
      @path = File.expand_path(@path) if @path

      # If path is given as the second arg
      if @dir && File.extname(@dir) != ""
        @dir, @path = nil, @dir
      end

      # Default dir to the directory of the path
      @dir ||= File.dirname(@path) if @path

      # If directory is given w/o path, pick a random manifest.json location
      if @dir && @path.nil?
        # Find the first manifest.json in the directory
        paths = Dir[File.join(@dir, "manifest*.json")]
        if paths.any?
          @path = paths.first
        else
          @path = File.join(@dir, "manifest-#{SecureRandom.hex(16)}.json")
        end
      end

      unless @dir && @path
        raise ArgumentError, "manifest requires output path"
      end

      data = nil

      begin
        if File.exist?(@path)
          data = json_decode(File.read(@path))
        end
      rescue MultiJson::DecodeError => e
        logger.error "#{@path} is invalid: #{e.class} #{e.message}"
      end

      @data = data.is_a?(Hash) ? data : {}
    end

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

    # Stores last compile time of assets
    def compiled_at=(iso8601)
      @data['compiled_at'] = iso8601
    end

    # Returns last compile time of assets
    def compiled_at
      @data['compiled_at'] || false
    end

    # Returns internal assets that have been moved from
    # directory. Keys are filenames which map to an
    # attributes array
    #
    #   Fingerprint path (String):
    #     logical_path: Logical path (String)
    #     mtime: ISO8601 mtime (String)
    #     digest: Base64 hex digest (String)
    #     generation: Survived cleans (Integer)
    #
    #  { "application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js" =>
    #      { 'logical_path' => "application.js",
    #        'mtime' => "2011-12-13T21:47:08-06:00",
    #        'digest' => "2e8e9a7c6b0aafa0c9bdeec90ea30213",
    #        'generation' => 1 } }
    def deleted_assets
      @data['deleted_assets'] ||= {}
    end

    # Returns internal file directory listing. Keys are filenames
    # which map to an attributes array.
    #
    #   Fingerprint path (String):
    #     logical_path: Logical path (String)
    #     mtime: ISO8601 mtime (String)
    #     digest: Base64 hex digest (String)
    #     compiled_at: ISO8601 compiled time (String)
    #
    #  { "application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js" =>
    #      { 'logical_path' => "application.js",
    #        'mtime' => "2011-12-13T21:47:08-06:00",
    #        'digest' => "2e8e9a7c6b0aafa0c9bdeec90ea30213",
    #        'compiled_at' => "2013-11-10T11:37:08-06:00"} }
    #
    def files
      @data['files'] ||= {}
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

      paths = environment.each_logical_path(*args).to_a +
        args.flatten.select { |fn| Pathname.new(fn).absolute? if fn.is_a?(String)}

      self.compiled_at = Time.now.utc.iso8601(6)
      paths.each do |path|
        if asset = find_asset(path)
          files[asset.digest_path] = {
            'logical_path' => asset.logical_path,
            'mtime'        => asset.mtime.iso8601,
            'size'         => asset.bytesize,
            'digest'       => asset.digest,
            'compiled_at'  => compiled_at
          }
          assets[asset.logical_path] = asset.digest_path
          deleted_assets.delete(asset.logical_path)

          target = File.join(dir, asset.digest_path)

          if File.exist?(target)
            logger.debug "Skipping #{target}, already exists"
          else
            logger.info "Writing #{target}"
            asset.write_to target
            asset.write_to "#{target}.gz" if asset.is_a?(BundledAsset)
          end
        end
      end
      save
    end

    # Removes file from directory and from manifest. `filename` must
    # be the name with any directory path.
    #
    #   manifest.remove("application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js")
    #
    def remove(filename)
      path = File.join(dir, filename)
      gzip = "#{path}.gz"
      logical_path = files[filename]['logical_path']

      if assets[logical_path] == filename
        assets.delete(logical_path)
      end

      files.delete(filename)
      deleted_assets.delete(logical_path)
      FileUtils.rm(path) if File.exist?(path)
      FileUtils.rm(gzip) if File.exist?(gzip)

      save

      logger.info "Removed #{filename}"
      nil
    end

    # Cleanup old assets in the compile directory. By default it will
    # keep the latest version plus 2 backups.
    def clean(keep = 2)
      self.assets.each do |logical_path, file_name|
        # Get assets sorted by ctime, newest first
        assets = backups_for(logical_path)
        # Remove old assets
        old_assets = assets[keep..-1] || [] # Keep the last N backups
        old_assets.each { |path, _| remove(path) }

        # Remove deleted assets
        remove_if_deleted(file_name, keep)
      end
    end

    # Wipe directive
    def clobber
      FileUtils.rm_r(@dir) if File.exist?(@dir)
      logger.info "Removed #{@dir}"
      nil
    end

    protected
      # Remove deleted files in the compile directory. By default it
      # will only remove the file after a given number of deploys have
      # passed
      def remove_if_deleted(file, keep)
        asset        = files[file]
        logical_path = asset['logical_path']
        return true unless asset_removed?(asset)
        deleted      = deleted_assets.fetch(logical_path) { asset }
        generation   = deleted['generation'] ||= 0
        if generation >= keep
          remove(file)
        else
          deleted.merge!('generation' => generation + 1)
          save
        end
      end

      def asset_removed?(asset) # :nodoc:
        return false unless asset['compiled_at']
        return false unless compiled_at
        Time.parse(compiled_at) > Time.parse(asset['compiled_at'])
      end

      # Finds all the backup assets for a logical path. The latest
      # version is always excluded. The return array is sorted by the
      # assets mtime in descending order (Newest to oldest).
      def backups_for(logical_path)
        files.select { |filename, attrs|
          # Matching logical paths
          attrs['logical_path'] == logical_path &&
            # Excluding whatever asset is the current
            assets[logical_path] != filename
        }.sort_by { |filename, attrs|
          # Sort by timestamp
          Time.parse(attrs['mtime'])
        }.reverse
      end

      # Basic wrapper around Environment#find_asset. Logs compile time.
      def find_asset(logical_path)
        asset = nil
        ms = benchmark do
          asset = environment.find_asset(logical_path)
        end
        logger.debug "Compiled #{logical_path}  (#{ms}ms)"
        asset
      end

      # Persist manfiest back to FS
      def save
        FileUtils.mkdir_p dir
        File.open(path, 'w') do |f|
          f.write json_encode(@data)
        end
      end

    private
      # Feature detect newer MultiJson API
      if MultiJson.respond_to?(:dump)
        def json_decode(obj)
          MultiJson.load(obj)
        end

        def json_encode(obj)
          MultiJson.dump(obj)
        end
      else
        def json_decode(obj)
          MultiJson.decode(obj)
        end

        def json_encode(obj)
          MultiJson.encode(obj)
        end
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

      def benchmark
        start_time = Time.now.to_f
        yield
        ((Time.now.to_f - start_time) * 1000).to_i
      end
  end
end
