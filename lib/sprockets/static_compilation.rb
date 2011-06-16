require 'sprockets/static_asset'

require 'fileutils'
require 'pathname'

module Sprockets
  module StaticCompilation
    def static_root
      @static_root
    end

    def static_root=(root)
      expire_index!
      @static_root = root ? Pathname.new(root) : nil
    end

    def precompile(*paths)
      raise "missing static root" unless static_root

      paths.each do |path|
        files.each do |logical_path|
          if path.is_a?(Regexp)
            next unless path.match(logical_path.to_s)
          else
            next unless logical_path.fnmatch(path.to_s)
          end

          if asset = find_asset_in_path(logical_path)
            attributes  = attributes_for(logical_path)
            digest_path = attributes.path_with_fingerprint(asset.digest)
            filename    = static_root.join(digest_path)

            FileUtils.mkdir_p filename.dirname
            asset.write_to(filename)
            if processors(asset.content_type).any?
              asset.write_to("#{filename}.gz")
            end
          end
        end
      end
    end

    protected
      def compute_digest
        super.update(static_root.to_s)
      end

      def find_asset_in_static_root(logical_path)
        return unless static_root

        pathname   = Pathname.new(static_root.join(logical_path))
        attributes = attributes_for(pathname)

        entries = entries(pathname.dirname)

        if entries.empty?
          return nil
        end

        if !attributes.path_fingerprint
          pattern = /^#{Regexp.escape(attributes.basename_without_extensions.to_s)}
                     -([0-9a-f]{7,40})
                     #{Regexp.escape(attributes.extensions.join)}$/x

          entries.each do |filename|
            if filename.to_s =~ pattern
              asset = StaticAsset.new(self, logical_path, pathname.dirname.join(filename), $1)
              return asset
            end
          end
        end

        if entries.include?(pathname.basename) && pathname.file?
          asset = StaticAsset.new(self, logical_path, pathname)
          return asset
        end

        nil
      end

    private
      def files
        files = Set.new
        paths.each do |base_path|
          base_pathname = Pathname.new(base_path)
          Dir["#{base_pathname}/**/*"].each do |filename|
            logical_path = Pathname.new(filename).relative_path_from(base_pathname)
            files << attributes_for(logical_path).without_engine_extensions
          end
        end
        files
      end
  end
end
