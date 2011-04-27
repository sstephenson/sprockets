require 'tilt'

module Sprockets
  class ScssTemplate < Tilt::ScssTemplate
    self.default_mime_type = 'text/css'

    class Importer
      attr_reader :context

      def initialize(context)
        @context = context
      end

      def find_relative(name, base, options)
        pathname = context.sprockets_resolve("./#{name}")
        Sass::Engine.new(pathname.read, options.merge(:importer => self))
      end

      def find(name, options)
        pathname = context.sprockets_resolve(name)
        Sass::Engine.new(pathname.read, options.merge(:importer => self))
      end

      def mtime(name, options)
        if pathname = context.sprockets_resolve("./#{name}")
          pathname.mtime
        end
      end

      def key(name, options)
        ["Sprockets:" + File.dirname(File.expand_path(name)), File.basename(name)]
      end
    end

    def prepare
    end

    def evaluate(scope, locals, &block)
      Sass::Engine.new(data, {
        :filename => eval_file,
        :line => line,
        :syntax => :scss,
        :importer => Importer.new(scope)
      }).render
    end
  end
end
