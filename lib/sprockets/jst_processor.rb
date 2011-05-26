require 'tilt'

module Sprockets
  class JstProcessor < Tilt::Template
    def self.default_mime_type
      'application/javascript'
    end

    def prepare
    end

    def evaluate(scope, locals, &block)
      <<-JST
window.JST || (window.JST = {});
window.JST[#{scope.logical_path.inspect}] = #{data};
      JST
    end
  end
end
