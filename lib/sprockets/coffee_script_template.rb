module Sprockets
  class CoffeeScriptTemplate < Template
    def self.default_mime_type
      'application/javascript'
    end

    def render(context)
      require 'coffee_script' unless defined? ::CoffeeScript
      @output ||= CoffeeScript.compile(data)
    end
  end
end
