module Sprockets
  class SourceMapProcessor
    def self.call(input)
      case input[:content_type]
      when "application/js-sourcemap+json"
        accept = "application/javascript"
      when "application/css-sourcemap+json"
        accept = "text/css"
      else
        fail input[:content_type]
      end

      uri, _ = input[:environment].resolve!(input[:filename], accept: accept)
      asset = input[:environment].load(uri)

      asset.metadata[:map].to_json
    end
  end
end
