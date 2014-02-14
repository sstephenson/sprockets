module Sprockets
  # Also see `SassImporter` for more infomation.
  class SassTemplate < Template
    def self.default_mime_type
      'text/css'
    end

    def syntax
      :sass
    end

    def render(context)
      require 'sass' unless defined? ::Sass

      unless ::Sass::Script::Functions < Sprockets::SassFunctions
        # Install custom functions. It'd be great if this didn't need to
        # be installed globally, but could be passed into Engine as an
        # option.
        ::Sass::Script::Functions.send :include, Sprockets::SassFunctions
      end


      # Use custom importer that knows about Sprockets Caching
      cache_store = SassCacheStore.new(context.environment)

      options = {
        :filename => context.pathname.to_s,
        :syntax => syntax,
        :cache_store => cache_store,
        :importer => SassImporter.new(context, context.pathname),
        :load_paths => context.environment.paths.map { |path| SassImporter.new(context, path) },
        :sprockets => {
          :context => context,
          :environment => context.environment
        }
      }

      ::Sass::Engine.new(data, options).render
    rescue ::Sass::SyntaxError => e
      # Annotates exception message with parse line number
      context.__LINE__ = e.sass_backtrace.first[:line]
      raise e
    end
  end
end
