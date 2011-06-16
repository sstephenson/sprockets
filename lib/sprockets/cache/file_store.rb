require 'digest/md5'
require 'fileutils'
require 'pathname'

module Sprockets
  module Cache
    class FileStore
      def initialize(root)
        @root = Pathname.new(root)
        FileUtils.mkdir_p @root
      end

      def [](key)
        pathname = path_for(key)
        pathname.exist? ? pathname.open('rb') { |f| Marshal.load(f) } : nil
      end

      def []=(key, value)
        path_for(key).open('w') { |f| Marshal.dump(value, f)}
        value
      end

      private
        def path_for(key)
          @root.join(::Digest::MD5.hexdigest(key))
        end
    end
  end
end
