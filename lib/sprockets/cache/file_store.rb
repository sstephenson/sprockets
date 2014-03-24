require 'digest/md5'
require 'fileutils'
require 'pathname'

module Sprockets
  module Cache
    # A simple file system cache store.
    #
    #     environment.cache = Sprockets::Cache::FileStore.new("/tmp")
    #
    class FileStore
      DEFAULT_MAX_SIZE = 1000

      def initialize(root, max_size = DEFAULT_MAX_SIZE)
        @root = root
        @size = find_caches.size
        @max_size = max_size
      end

      # Lookup value in cache
      def [](key)
        path = File.join(@root, "#{key}.cache")

        if File.exist?(path)
          value = File.open(path, 'rb') { |f| Marshal.load(f) }
          FileUtils.touch(path)
          value
        else
          nil
        end
        rescue
          nil
      end

      # Save value to cache
      def []=(key, value)
        path = File.join(@root, "#{key}.cache")

        # Ensure directory exists
        FileUtils.mkdir_p File.dirname(path)

        # Check if cache exists before writing
        exists = File.exist?(path)

        # Write data
        atomic_write(path) do |file|
          file.write(Marshal.dump(value, file))
        end

        # GC if necessary
        @size += 1 unless exists
        gc! if @size > @max_size

        value
      end

      private
        # extracted from https://github.com/rails/rails/blob/master/activesupport/lib/active_support/core_ext/file/atomic.rb
        def atomic_write(file_name, temp_dir = Dir.tmpdir)
          require 'tempfile' unless defined?(Tempfile)
          require 'fileutils' unless defined?(FileUtils)

          temp_file = Tempfile.new(File.basename(file_name), temp_dir)
          temp_file.binmode
          yield temp_file
          temp_file.close

          if File.exist?(file_name)
            # Get original file permissions
            old_stat = File.stat(file_name)
          else
            # If not possible, probe which are the default permissions in the
            # destination directory.
            old_stat = probe_stat_in(File.dirname(file_name))
          end

          # Overwrite original file with temp file
          FileUtils.mv(temp_file.path, file_name)

          # Set correct permissions on new file
          begin
            File.chown(old_stat.uid, old_stat.gid, file_name)
            # This operation will affect filesystem ACL's
            File.chmod(old_stat.mode, file_name)
          rescue Errno::EPERM
            # Changing file ownership failed, moving on.
          end
        end

        def probe_stat_in(dir)
          basename = [
            '.permissions_check',
            Thread.current.object_id,
            Process.pid,
            rand(1000000)
          ].join('.')

          file_name = File.join(dir, basename)
          FileUtils.touch(file_name)
          File.stat(file_name)
        ensure
          FileUtils.rm_f(file_name) if file_name
        end

        def find_caches
          Dir.glob(File.join(@root, '**/*.cache'))
        end

        def gc!
          caches = find_caches

          new_size = @max_size * 0.75
          num_to_delete = caches.size - new_size
          return unless num_to_delete > 0

          caches.sort_by! { |path| -File.mtime(path).to_i }
          FileUtils.remove(caches[0, num_to_delete], force: true)

          @size = find_caches.size
        end
    end
  end
end
