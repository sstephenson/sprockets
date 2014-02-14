require 'sprockets/sass_template'

module Sprockets
  class ScssTemplate < SassTemplate
    def self.default_mime_type
      'text/css'
    end

    def syntax
      :scss
    end
  end
end
