require 'tilt'

module Sprockets
  class EcoTemplate < Tilt::Template
    def self.default_mime_type
      'application/javascript'
    end

    def initialize_engine
      require_template_library 'reco'
    end

    def prepare
    end

    def evaluate(scope, locals, &block)
      # cut off the trailing ;
      raw=Reco.compile(data)[0..-2]
      # remove the variable assignment so we just return a raw function (same as Ejs)
      raw.gsub(/^module.exports = /,"")
    end
  end
end
