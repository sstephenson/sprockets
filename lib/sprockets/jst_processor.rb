module Sprockets
  class JstProcessor < Template
    def self.default_mime_type
      'application/javascript'
    end

    def self.default_namespace
      'this.JST'
    end

    def render(context)
      namespace = self.class.default_namespace
      <<-JST
(function() { #{namespace} || (#{namespace} = {}); #{namespace}[#{context.logical_path.inspect}] = #{indent(data)};
}).call(this);
      JST
    end

    private
      def indent(string)
        string.gsub(/$(.)/m, "\\1  ").strip
      end
  end
end
