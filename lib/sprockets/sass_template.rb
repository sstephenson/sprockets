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
      # cache_store = SassCacheStore.new(context.environment)

      options = {
        :filename => context.pathname.to_s,
        :syntax => syntax,
        :cache => false,
        :read_cache => false,
        :importer => SassImporter.new(context, context.pathname),
        :load_paths => context.environment.paths.map { |path| SassImporter.new(context, path) },
        :sprockets => {
          :context => context,
          :environment => context.environment
        }
      }

      ::Sass::Engine.new(data, options).render
    rescue ::Sass::SyntaxError => exception
      # Annotates exception message with erb comment if applies, and with
      # parse line number
      annotate_exception!(exception, context.pathname)
      context.__LINE__ = exception.sass_backtrace.first[:line]
      raise exception
    end

    def annotate_exception!(exception, pathname)
      return false unless missing_erb_extension?(pathname)
      exception.extend(Sprockets::EngineError)
      exception.sprockets_annotation = "You are using erb in your file: " +
        "#{pathname} but have not added the .erb extension.\n" +
        "Please change the file name to #{pathname}.erb and try again."
    end

    def missing_erb_extension?(pathname)
      erb_extension = pathname.to_s.split('/').last.match(/erb\Z/)
      has_erb_tags = File.read(pathname) =~ /<%=?(.+)%>/
      !erb_extension && has_erb_tags
    end
  end
end
