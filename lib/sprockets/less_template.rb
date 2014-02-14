module Sprockets
  class LessTemplate < Template
    def self.default_mime_type
      'text/css'
    end

    def render(context)
      require 'less' unless defined? ::Less

      if ::Less.const_defined? :Engine
        engine = ::Less::Engine.new(data)
      else
        parser = ::Less::Parser.new(:filename => context.pathname.to_s)
        engine = parser.parse(data)
      end

      engine.to_css
    end
  end
end
