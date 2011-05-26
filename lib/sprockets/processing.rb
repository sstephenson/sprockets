require 'sprockets/compressor'
require 'sprockets/engines'
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

    def register_processor(mime_type, klass)
      expire_index!
      @processors[mime_type].push(klass)
    end

    def unregister_processor(mime_type, klass)
      expire_index!
      @processors[mime_type].delete(klass)
    end

    def bundle_processors(mime_type = nil)
      if mime_type
        @bundle_processors[mime_type].dup
      else
        deep_copy_hash(@bundle_processors)
      end
    end

    def register_bundle_processor(mime_type, klass)
      expire_index!
      @bundle_processors[mime_type].push(klass)
    end

    def unregister_bundle_processor(mime_type, klass)
      expire_index!
      @bundle_processors[mime_type].delete(klass)
    end

    def css_compressor
      bundle_processors('text/css').detect { |klass|
        klass.respond_to?(:name) &&
          klass.name == 'Sprockets::Compressor'
      }
    end

    def css_compressor=(compressor)
      expire_index!

      if old_compressor = css_compressor
        unregister_bundle_processor 'text/css', old_compressor
      end

      if compressor
        klass = Class.new(Compressor) do
          @compressor = compressor
        end

        register_bundle_processor 'text/css', klass
      end
    end

    def js_compressor
      bundle_processors('application/javascript').detect { |klass|
        klass.respond_to?(:name) &&
          klass.name == 'Sprockets::Compressor'
      }
    end

    def js_compressor=(compressor)
      expire_index!

      if old_compressor = js_compressor
        unregister_bundle_processor 'application/javascript', old_compressor
      end

      if compressor
        klass = Class.new(Compressor) do
          @compressor = compressor
        end

        register_bundle_processor 'application/javascript', klass
      end
    end

    private
      def deep_copy_hash(hash)
        initial = Hash.new { |h, k| h[k] = [] }
        hash.inject(initial) { |h, (k, a)| h[k] = a.dup; h }
      end
  end
end
