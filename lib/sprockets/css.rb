require 'tilt'

module Sprockets
  class SassTemplate < Tilt::SassTemplate
    self.default_mime_type = 'text/css'

    def syntax
      :sass
    end

    def prepare
    end

    def evaluate(scope, locals, &block)
      importer = SassImporter.new(scope)
      Sass::Engine.new(data, {
        :filename => eval_file,
        :line => line,
        :syntax => syntax,
        :importer => importer,
        :load_paths => [importer]
      }).render
    end
  end

  class ScssTemplate < SassTemplate
    self.default_mime_type = 'text/css'

    def syntax
      :scss
    end
  end
end
