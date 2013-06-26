require 'tilt'

module Sprockets
  class UglifierCompressor < Tilt::Template
    self.default_mime_type = 'application/javascript'

    class << self
      attr_accessor :keep_copyrights

      def engine_initialized?
        defined?(::Uglifier)
      end
    end


    def initialize_engine
      require_template_library 'uglifier'
    end

    def prepare
    end

    def evaluate(context, locals, &block)
      keep_copyrights = !!self.class.keep_copyrights

      # Feature detect Uglifier 2.0 option support
      if Uglifier::DEFAULTS[:copyright]
        # Uglifier < 2.x
        Uglifier.new(:copyright => keep_copyrights).compile(data)
      else
        # Uglifier >= 2.x
        options = { :comments => :none }
        options[:comments] = :copyright if keep_copyrights

        Uglifier.new(options).compile(data)
      end

    end
  end
end
