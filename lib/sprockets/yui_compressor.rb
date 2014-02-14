module Sprockets
  class YUICompressor < Template
    def render(context)
      require 'yui/compressor' unless defined? ::YUI

      case context.content_type
      when 'application/javascript'
        YUI::JavaScriptCompressor.new.compress(data)
      when 'text/css'
        YUI::CssCompressor.new.compress(data)
      else
        data
      end
    end
  end
end
