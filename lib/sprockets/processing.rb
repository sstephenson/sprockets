require 'sprockets/engines'
require 'sprockets/processor'
require 'sprockets/utils'
require 'rack/mime'

module Sprockets
  module Processing
    include Engines

    def mime_types(ext = nil)
      if ext.nil?
        Rack::Mime::MIME_TYPES.merge(@mime_types)
      else
        ext = Sprockets::Utils.normalize_extension(ext)
        @mime_types[ext] || Rack::Mime::MIME_TYPES[ext]
      end
    end

    def register_mime_type(mime_type, ext)
      expire_index!
      ext = Sprockets::Utils.normalize_extension(ext)
      @trail.extensions << ext
      @mime_types[ext] = mime_type
    end

    def format_extensions
      @trail.extensions - @engines.keys
    end

    def register_engine(ext, klass)
      expire_index!
      @trail.extensions << ext.to_s
      super
    end

    def processors(mime_type = nil)
      if mime_type
        @processors[mime_type].dup
      else
        deep_copy_hash(@processors)
      end
    end

    def register_processor(mime_type, klass, &block)
      expire_index!

      if block_given?
        name  = klass.to_s
        klass = Class.new(Processor) do
          @name      = name
          @processor = block
        end
      end

      @processors[mime_type].push(klass)
    end

    def unregister_processor(mime_type, klass)
      expire_index!

      if klass.is_a?(String) || klass.is_a?(Symbol)
        klass = @processors[mime_type].detect { |cls|
          cls.respond_to?(:name) &&
            cls.name == "Sprockets::Processor (#{klass})"
        }
      end

      @processors[mime_type].delete(klass)
    end

    def bundle_processors(mime_type = nil)
      if mime_type
        @bundle_processors[mime_type].dup
      else
        deep_copy_hash(@bundle_processors)
      end
    end

    def register_bundle_processor(mime_type, klass, &block)
      expire_index!

      if block_given?
        name  = klass.to_s
        klass = Class.new(Processor) do
          @name      = name
          @processor = block
        end
      end

      @bundle_processors[mime_type].push(klass)
    end

    def unregister_bundle_processor(mime_type, klass)
      expire_index!

      if klass.is_a?(String) || klass.is_a?(Symbol)
        klass = @bundle_processors[mime_type].detect { |cls|
          cls.respond_to?(:name) &&
            cls.name == "Sprockets::Processor (#{klass})"
        }
      end

      @bundle_processors[mime_type].delete(klass)
    end

    def css_compressor
      bundle_processors('text/css').detect { |klass|
        klass.respond_to?(:name) &&
          klass.name == 'Sprockets::Processor (css_compressor)'
      }
    end

    def css_compressor=(compressor)
      expire_index!

      unregister_bundle_processor 'text/css', :css_compressor
      return unless compressor

      register_bundle_processor 'text/css', :css_compressor do |context, data|
        compressor.compress(data)
      end
    end

    def js_compressor
      bundle_processors('application/javascript').detect { |klass|
        klass.respond_to?(:name) &&
          klass.name == 'Sprockets::Processor (js_compressor)'
      }
    end

    def js_compressor=(compressor)
      expire_index!

      unregister_bundle_processor 'application/javascript', :js_compressor
      return unless compressor

      register_bundle_processor 'application/javascript', :js_compressor do |context, data|
        compressor.compress(data)
      end
    end

    protected
      def compute_digest
        digest = super

        digest << @mime_types.keys.join(',')
        digest << @engines.map { |e, k| "#{e}:#{k.name}" }.join(',')
        digest << @processors.map { |m, a| "#{m}:#{a.map(&:name)}" }.join(',')
        digest << @bundle_processors.map { |m, a| "#{m}:#{a.map(&:name)}" }.join(',')

        digest
      end

    private
      def deep_copy_hash(hash)
        initial = Hash.new { |h, k| h[k] = [] }
        hash.inject(initial) { |h, (k, a)| h[k] = a.dup; h }
      end
  end
end
