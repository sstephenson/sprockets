require 'tilt'

module Sprockets
  class LessTemplate < Tilt::Template
    self.default_mime_type = 'text/css'

    def self.engine_initialized?
      defined?(::Less)
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
      parser = ::Less::Parser.new(options)
      parser.imports.each do |path|
        pathname = context.resolve(path) rescue nil
        context.depend_on(pathname) if pathname
      end
      parser.parse(data).to_css
    rescue ::Less::ParseError => e
      context.__LINE__ = e.line
      raise e
    end
  end
end
