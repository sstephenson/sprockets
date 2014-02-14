module Sprockets
  class ClosureCompressor < Template
    def self.default_mime_type
      'application/javascript'
    end

    def render(context)
      require 'closure-compiler' unless defined? ::Closure::Compiler
      Closure::Compiler.new.compile(data)
    end
  end
end
