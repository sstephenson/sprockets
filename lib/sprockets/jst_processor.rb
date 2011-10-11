require 'tilt'

module Sprockets
  class JstProcessor < Tilt::Template

    @namespace = 'this.JST'
    class << self
      attr_accessor :namespace
    end

    def self.default_mime_type
      'application/javascript'
    end

    def prepare
    end

    def evaluate(scope, locals, &block)
      <<-JST
(function() {
  #{self.class.namespace} || (#{self.class.namespace} = {});
  #{self.class.namespace}[#{scope.logical_path.inspect}] = #{indent(data)};
}).call(this);
      JST
    end

    private
      def indent(string)
        string.gsub(/$(.)/m, "\\1  ").strip
      end
  end
end
