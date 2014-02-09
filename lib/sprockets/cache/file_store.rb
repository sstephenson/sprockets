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
      def initialize(root)
        @root = Pathname.new(root)
      end

      # Lookup value in cache
      def [](key)
        pathname = @root.join(key)

        if pathname.exist?  
          pathname.open('rb') { |f| Marshal.load(f) }
        else
          nil
        end
      end

      # Save value to cache
      def []=(key, value)
        # Ensure directory exists
        FileUtils.mkdir_p @root.join("#{key}.lock").dirname

        if @root.join("#{key}.lock").exist?
          puts "File Locked; Currently caching to this file, so skipping"
        else
          # Lock the File to prevent threads from stomping on each other.
          @root.join("#{key}.lock").open('wb') {|f| f.puts 'locked' }

          # Atomic write
          @root.join("#{key}+").open('wb') { |f| Marshal.dump(value, f)}
          FileUtils.mv(@root.join("#{key}+"), @root.join(key))

          # Unlock
          FileUtils.rm_rf @root.join("#{key}.lock")
        end

        value
      end
    end
  end
end
