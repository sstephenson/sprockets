require 'sprockets/engine_pathname'
require 'sprockets/errors'
require 'pathname'

#### Sprockets::Context
#
# The context class keeps track of an environment, basepath, and the logical path for a pathname
# TODO Fill in with better explanation
module Sprockets
  class Context
    attr_reader :sprockets_environment
    attr_reader :pathname

    def initialize(environment, concatenation, pathname)
      @_sprockets_concatenation = concatenation
      @sprockets_environment    = environment
      @pathname                 = pathname
    end

    def root_path
      sprockets_environment.paths.detect { |path| pathname.to_s[path] }
    end

    def logical_path
      if pathname && root_path
        pathname.to_s[%r{^#{root_path}\/([^.]+)}, 1]
      end
    end

    def content_type
      EnginePathname.new(pathname, sprockets_environment.engines).content_type
    end

    def sprockets_resolve(path, &block)
      sprockets_environment.resolve(path, :base_path => pathname.dirname, &block)
    end

    def sprockets_depend(path)
      @_sprockets_concatenation.depend(_expand_path(path))
    end

    def sprockets_require(path)
      pathname        = Pathname.new(path)
      engine_pathname = EnginePathname.new(pathname, sprockets_environment.engines)

      if engine_pathname.format_extension
        if self.content_type != engine_pathname.content_type
          raise ContentTypeMismatch, "#{path} is " +
            "'#{engine_pathname.format_extension}', not '#{EnginePathname.new(self.pathname, sprockets_environment.engines).format_extension}'"
        end
      end

      if pathname.absolute?
        @_sprockets_concatenation.require(pathname)
      else
        sprockets_resolve(path) do |candidate|
          engine_pathname = EnginePathname.new(candidate, sprockets_environment.engines)

          if self.content_type == engine_pathname.content_type
            @_sprockets_concatenation.require(candidate)
            return
          end
        end

        raise FileNotFound, "couldn't find file '#{path}'"
      end
    end

    def sprockets_process(path)
      @_sprockets_concatenation.process(_expand_path(path))
    end

    private
      def _expand_path(path)
        pathname = Pathname.new(path)
        pathname.absolute? ? pathname : resolve(pathname)
      end
  end
end
