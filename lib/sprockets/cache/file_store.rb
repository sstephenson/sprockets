require 'digest/md5'
require 'fileutils'
require 'logger'
require 'tempfile'

module Sprockets
  class Cache
    # Public: A file system cache store that automatically cleans up old keys.
    #
    # Assign the instance to the Environment#cache.
    #
    #     environment.cache = Sprockets::Cache::FileStore.new("/tmp")
    #
    # See Also
    #
    #   ActiveSupport::Cache::FileStore
    #
    class FileStore
      # Internal: Default key limit for store.
      DEFAULT_MAX_SIZE = 1000

      # Internal: Default standard error fatal logger.
      #
      # Returns a Logger.
      def self.default_logger
        logger = Logger.new($stderr)
        logger.level = Logger::FATAL
        logger
      end

      # Public: Initialize the cache store.
      #
      # root     - A String path to a directory to persist cached values to.
      # max_size - A Integer of the maximum number of keys the store will hold.
      #            (default: 1000).
      def initialize(root, max_size = DEFAULT_MAX_SIZE, logger = self.class.default_logger)
        @root = root
        @size = find_caches.size
        @max_size = max_size
        @logger = logger
        @tmpdir = Dir.tmpdir
      end

      # Public: Retrieve value from cache.
      #
      # This API should not be used directly, but via the Cache wrapper API.
      #
      # key - String cache key.
      #
      # Returns Object or nil or the value is not set.
      def get(key)
        path = File.join(@root, "#{key}.cache")

        if File.exist?(path)
          value = File.open(path, 'rb') do |f|
            begin
              Marshal.load(f)
            rescue Exception => e
              @logger.error do
                "#{self.class}[#{path}] could not be unmarshaled: " +
                  "#{e.class}: #{e.message}"
              end
              nil
            end
          end
          FileUtils.touch(path)
          value
        else
          nil
        end
      end

      # Public: Set a key and value in the cache.
      #
      # This API should not be used directly, but via the Cache wrapper API.
      #
      # key   - String cache key.
      # value - Object value.
      #
      # Returns Object value.
      def set(key, value)
        path = File.join(@root, "#{key}.cache")

        # Ensure directory exists
        FileUtils.mkdir_p File.dirname(path)

        # Check if cache exists before writing
        exists = File.exist?(path)

        # Write data
        PathUtils.atomic_write(path, @tmpdir) { |f| Marshal.dump(value, f) }

        # GC if necessary
        @size += 1 unless exists
        gc! if @size > @max_size

        value
      end

      # Public: Pretty inspect
      #
      # Returns String.
      def inspect
        "#<#{self.class} size=#{@size}/#{@max_size}>"
      end

      private
        def find_caches
          Dir.glob(File.join(@root, '**/*.cache'))
        end

        def gc!
          start_time = Time.now
          caches = find_caches

          new_size = @max_size * 0.75
          num_to_delete = caches.size - new_size
          return unless num_to_delete > 0

          caches.sort_by! { |path| -File.mtime(path).to_i }
          FileUtils.remove(caches[0, num_to_delete], force: true)

          @size = find_caches.size

          @logger.warn do
            secs = Time.now.to_f - start_time.to_f
            "#{self.class}[#{@root}] garbage collected " +
              "#{num_to_delete.to_i} files (#{(secs * 1000).to_i}ms)"
          end
        end
    end
  end
end
