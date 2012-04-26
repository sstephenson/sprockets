require 'tilt'

module Sprockets
  class LessTemplate < Tilt::Template
    self.default_mime_type = 'text/css'

    IMPORT_SCANNER = /@import\s*['"]([^'"]+)['"]\s*;/.freeze

    def self.engine_initialized?
      defined? ::Less
    end

    def initialize_engine
      require_template_library 'less'
    end

    def prepare
    end

    def evaluate(context, locals, &block)
      options = {
        :filename => eval_file,
        :line => line,
        :paths => context.environment.paths
      }
      ::Less.Parser['scope'] = context
      depend_on(context, data)
      ::Less::Parser.new(options).parse(data).to_css
    rescue ::Less::ParseError => e
      context.__LINE__ = e.line
      raise e
    end

    protected
      def depend_on(context, data)
        import_paths = data.scan(IMPORT_SCANNER).flatten.compact.uniq
        import_paths.each do |path|
          pathname = context.resolve(path) rescue nil
          context.depend_on(path) if pathname && pathname.to_s =~ /.less$/
          depend_on context, File.read(pathname) if pathname
        end
      end
  end
end
