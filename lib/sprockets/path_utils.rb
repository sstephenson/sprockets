require 'fileutils'
require 'tempfile'
require 'pathname'

module Sprockets
  # Internal: File and path related utilities. Mixed into Environment.
  #
  # Probably would be called FileUtils, but that causes namespace annoyances
  # when code actually wants to reference ::FileUtils.
  module PathUtils
    extend self

    # Internal: Like `File.stat`.
    #
    # path - String file or directory path
    #
    # Returns nil if the file does not exist.
    def stat(path)
      if File.exist?(path)
        File.stat(path.to_s)
      else
        nil
      end
    end

    # Internal: Like `File.file?`.
    #
    # path - String file path.
    #
    # Returns true path exists and is a file.
    def file?(path)
      if stat = self.stat(path)
        stat.file?
      else
        false
      end
    end

    # Internal: A version of `Dir.entries` that filters out `.` files and `~`
    # swap files.
    #
    # path - String directory path
    #
    # Returns an empty `Array` if the directory does not exist.
    def entries(path)
      if File.directory?(path)
        Dir.entries(path).reject { |entry| entry =~ /^\.|~$|^\#.*\#$/ }.sort
      else
        []
      end
    end

    # Internal: Check if path is absolute or relative.
    #
    # path - String path.
    #
    # Returns true if path is absolute, otherwise false.
    if File::ALT_SEPARATOR
      # On Windows, ALT_SEPARATOR is \
      def absolute_path?(path)
        path[0] == File::SEPARATOR || path[0] == File::ALT_SEPARATOR
      end
    else
      def absolute_path?(path)
        path[0] == File::SEPARATOR
      end
    end

    # Internal: Check if path is explicitly relative.
    # Starts with "./" or "../".
    #
    # path - String path.
    #
    # Returns true if path is relative, otherwise false.
    def relative_path?(path)
      path =~ /^\.\.?($|\/)/ ? true : false
    end

    # Internal: Get relative path for root path and subpath.
    #
    # path    - String path
    # subpath - String subpath of path
    #
    # Returns relative String path if subpath is a subpath of path, or nil if
    # subpath is outside of path.
    def split_subpath(path, subpath)
      path = Pathname.new(path).cleanpath.to_s + "/"
      subpath = Pathname.new(subpath).cleanpath.to_s

      if subpath.start_with?(path)
        subpath[path.length..-1]
      else
        nil
      end
    end

    # Internal: Detect root path and base for file in a set of paths.
    #
    # paths    - Array of String paths
    # filename - String path of file expected to be in one of the paths.
    #
    # Returns [String root, String path]
    def paths_split(paths, filename)
      paths.each do |path|
        if subpath = split_subpath(path, filename)
          return path, subpath
        end
      end
      nil
    end

    # Internal: Get path's extensions.
    #
    # path - String
    #
    # Returns an Array of String extnames.
    def path_extnames(path)
      File.basename(path).scan(/\.[^.]+/)
    end

    # Internal: Stat all the files under a directory.
    #
    # dir - A String directory
    #
    # Returns an Enumerator of [path, stat].
    def stat_directory(dir)
      return to_enum(__method__, dir) unless block_given?

      self.entries(dir).each do |entry|
        path = File.join(dir, entry)
        if stat = self.stat(path)
          yield path, stat
        end
      end

      nil
    end

    # Internal: Recursive stat all the files under a directory.
    #
    # dir - A String directory
    #
    # Returns an Enumerator of [path, stat].
    def stat_tree(dir, &block)
      return to_enum(__method__, dir) unless block_given?

      self.stat_directory(dir) do |path, stat|
        yield path, stat

        if stat.directory?
          stat_tree(path, &block)
        end
      end

      nil
    end

    # Internal: Write to a file atomically. Useful for situations where you
    # don't want other processes or threads to see half-written files.
    #
    #   Utils.atomic_write('important.file') do |file|
    #     file.write('hello')
    #   end
    #
    # If your temp directory is not on the same filesystem as the file you're
    # trying to write, you can provide a different temporary directory.
    #
    #   Utils.atomic_write('/data/something.important', '/data/tmp') do |file|
    #     file.write('hello')
    #   end
    #
    # Taken from ActiveSupport.
    #
    # https://github.com/rails/rails/blob/master/
    #   activesupport/lib/active_support/core_ext/file/atomic.rb
    def atomic_write(file_name, temp_dir = Dir.tmpdir)
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

    # Internal: Taken from ActiveSupport.
    #
    # https://github.com/rails/rails/blob/master/
    #   activesupport/lib/active_support/core_ext/file/atomic.rb
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
  end
end
