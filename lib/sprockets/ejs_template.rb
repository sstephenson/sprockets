require 'tilt'

module Sprockets
  class EjsTemplate < Tilt::Template
    def self.default_mime_type
      'application/javascript'
    end

    def initialize_engine
      require_template_library 'ejs'
    end

    def prepare
    end

    def evaluate(scope, locals, &block)
      EJS.compile(data)
    end
  end
end
