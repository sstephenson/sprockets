require 'sprockets/asset_pathname'
require 'sprockets/errors'
require 'pathname'
require 'set'

#### Sprockets::Context
#
# The context class keeps track of an environment, basepath, and the logical path for a pathname
# TODO Fill in with better explanation
module Sprockets
  class Context
    attr_reader :environment, :pathname
    attr_reader :_required_paths, :_dependency_paths

    def initialize(environment, logical_path, pathname)
      @environment  = environment
      @logical_path = logical_path
      @pathname     = pathname

      @_required_paths   = []
      @_dependency_paths = Set.new
    end

    def root_path
      environment.paths.detect { |path| pathname.to_s[path] }
    end

    def logical_path
      @logical_path[/^([^.]+)/, 0]
    end

    def content_type
      AssetPathname.new(pathname, environment).content_type
    end

    def resolve(path, options = {}, &block)
      pathname       = Pathname.new(path)
      asset_pathname = AssetPathname.new(pathname, environment)

      if pathname.absolute?
        pathname

      elsif content_type = options[:content_type]
        content_type = self.content_type if content_type == :self

        if asset_pathname.format_extension
          if content_type != asset_pathname.content_type
            raise ContentTypeMismatch, "#{path} is " +
              "'#{asset_pathname.content_type}', not '#{content_type}'"
          end
        end

        resolve(path) do |candidate|
          if self.content_type == AssetPathname.new(candidate, environment).content_type
            return candidate
          end
        end

        raise FileNotFound, "couldn't find file '#{path}'"
      else
        environment.resolve(path, :base_path => self.pathname.dirname, &block)
      end
    end

    def depend_on(path)
      @_dependency_paths << resolve(path).to_s
    end

    def evaluate(filename, options = {})
      pathname       = resolve(filename)
      asset_pathname = AssetPathname.new(pathname, environment)
      extension      = asset_pathname.format_extension ||
                         asset_pathname.engine_format_extension

      data     = options[:data] || pathname.read
      engines  = options[:engines] || environment.formats(extension) +
                          asset_pathname.engines.reverse

      engines.inject(data) do |result, engine|
        template = engine.new(pathname.to_s) { result }
        template.render(self, {})
      end
    end

    def asset_requirable?(path)
      pathname = resolve(path)
      content_type = AssetPathname.new(pathname, environment).content_type
      pathname.file? && (self.content_type.nil? || self.content_type == content_type)
    end

    def require_asset(path)
      pathname = resolve(path, :content_type => :self)

      unless @_required_paths.include?(pathname.to_s)
        @_dependency_paths << pathname.to_s
        @_required_paths << pathname.to_s
      end

      pathname
    end
  end
end
