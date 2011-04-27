require 'sprockets/concatenated_asset'
require 'sprockets/engine_pathname'
require 'sprockets/errors'
require 'sprockets/server'
require 'sprockets/static_asset'
require 'sprockets/utils'
require 'pathname'
require 'set'

module Sprockets
  class EnvironmentIndex
    include Server

    attr_reader :logger, :context, :engines, :css_compressor, :js_compressor

    attr_reader :static_root

    def initialize(environment, trail, static_root)
      @logger         = environment.logger
      @context        = environment.context
      @engines        = environment.engines.dup
      @css_compressor = environment.css_compressor
      @js_compressor  = environment.js_compressor

      @trail = trail.index
      @static_assets = {}
      @path_assets   = {}
      @entries = {}

      @static_root = static_root ? Pathname.new(static_root) : nil
    end

    def root
      @trail.root
    end

    def paths
      @trail.paths
    end

    def extensions
      @trail.extensions
    end

    def index
      self
    end

    def precompile(*paths)
      raise "missing static root" unless @static_root

      paths.each do |path|
        files.each do |logical_path|
          if path.is_a?(Regexp)
            next unless path.match(logical_path.to_s)
          else
            next unless logical_path.fnmatch(path.to_s)
          end

          if asset = find_asset_in_path(logical_path)
            digest_path = Utils.path_with_fingerprint(logical_path, asset.digest)
            filename = @static_root.join(digest_path)

            FileUtils.mkdir_p filename.dirname

            filename.open('w') do |f|
              f.write asset.to_s
            end
          end
        end
      end
    end

    def resolve(logical_path, options = {})
      if block_given?
        @trail.find(logical_path.to_s, logical_index_path(logical_path), options) do |path|
          yield Pathname.new(path)
        end
      else
        resolve(logical_path, options) do |pathname|
          return pathname
        end
        raise FileNotFound, "couldn't find file '#{logical_path}'"
      end
    end

    def find_asset(logical_path)
      logical_path = Pathname.new(logical_path)
      find_asset_in_static(logical_path) || find_asset_in_path(logical_path)
    end
    alias_method :[], :find_asset

    protected
      def files
        files = Set.new
        paths.each do |base_path|
          base_pathname = Pathname.new(base_path)
          Dir["#{base_pathname}/**/*"].each do |filename|
            logical_path = Pathname.new(filename).relative_path_from(base_pathname)
            files << path_without_engine_extensions(logical_path)
          end
        end
        files
      end

      def find_asset_in_static(logical_path)
        return unless static_root

        logical_path = logical_path.to_s.sub(/^\//, '')

        if @static_assets.key?(logical_path)
          return @static_assets[logical_path]
        end

        pathname = Pathname.new(static_root.join(logical_path))
        engine_pathname = EnginePathname.new(pathname, engines)

        entries = entries(pathname.dirname)

        if entries.empty?
          @static_assets[logical_path] = nil
          return nil
        end

        if !Utils.path_fingerprint(pathname)
          pattern = /^#{Regexp.escape(engine_pathname.basename_without_extensions.to_s)}
                     -[0-9a-f]{7,40}
                     #{Regexp.escape(engine_pathname.extensions.join)}$/x

          entries.each do |filename|
            if filename.to_s =~ pattern
              asset = StaticAsset.new(self, pathname.dirname.join(filename))
              @static_assets[logical_path] = asset
              return asset
            end
          end
        end

        if entries.include?(pathname.basename) && pathname.file?
          asset = StaticAsset.new(self, pathname)
          @static_assets[logical_path] = asset
          return asset
        end

        @static_assets[logical_path] = nil
        nil
      end

      def find_asset_in_path(logical_path)
        if @path_assets.key?(logical_path.to_s)
          return @path_assets[logical_path.to_s]
        end

        if fingerprint = Utils.path_fingerprint(logical_path)
          pathname = resolve(logical_path.to_s.sub("-#{fingerprint}", ''))
        else
          pathname = resolve(logical_path)
        end
      rescue FileNotFound
        nil
      else
        if engines.concatenatable?(pathname)
          logger.info "[Sprockets] #{logical_path} building"
          asset = ConcatenatedAsset.new(self, pathname)
        else
          asset = StaticAsset.new(self, pathname)
        end

        if fingerprint && fingerprint != asset.digest
          logger.error "[Sprockets] #{logical_path} #{fingerprint} nonexistent"
          asset = nil
        end

        @path_assets[logical_path.to_s] = asset
        asset
      end

    private
      def logical_index_path(logical_path)
        pathname = Pathname.new(logical_path)
        engine_pathname = EnginePathname.new(logical_path, engines)

        if engine_pathname.basename_without_extensions.to_s == 'index'
          logical_path
        else
          basename = "#{engine_pathname.basename_without_extensions}/index#{engine_pathname.extensions.join}"
          pathname.dirname.to_s == '.' ? basename : pathname.dirname.join(basename).to_s
        end
      end

      def path_without_engine_extensions(pathname)
        engine_pathname = EnginePathname.new(pathname, engines)
        engine_pathname.engine_extensions.inject(pathname) do |p, ext|
          p.sub(ext, '')
        end
      end

      def entries(pathname)
        @entries[pathname.to_s] ||= pathname.entries.reject { |entry| entry.to_s =~ /^\.\.?$/ }
      rescue Errno::ENOENT
        @entries[pathname.to_s] = []
      end
  end
end
