module Sprockets
  class SassCompressor < Template
    def self.default_mime_type
      'text/css'
    end

    def render(context)
      require 'sass' unless defined? ::Sass::Engine
      ::Sass::Engine.new(data, {
        :syntax => :scss,
        :cache => false,
        :read_cache => false,
        :style => :compressed
      }).render
    end
  end
end
