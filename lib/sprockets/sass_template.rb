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

      # Use custom importer that knows about Sprockets Caching
      cache_store = SassCacheStore.new(context.environment)

      options = {
        :filename => context.pathname.to_s,
        :syntax => syntax,
        :cache_store => cache_store,
        :load_paths => context.environment.paths,
        :sprockets => {
          :context => context,
          :environment => context.environment
        }
      }

      engine, css = nil, nil
      Sprockets::SassFunctions.define_functions(::Sass::Script::Functions) do
        engine = ::Sass::Engine.new(data, options)
        css = engine.render
      end

      # Track all imported files
      engine.dependencies.each do |dependency|
        context.depend_on(dependency.options[:filename])
      end

      css
    rescue ::Sass::SyntaxError => e
      # Annotates exception message with parse line number
      context.__LINE__ = e.sass_backtrace.first[:line]
      raise e
    end
  end
end
