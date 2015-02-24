require 'source_map'
require 'sprockets/mime'
require 'sprockets/processor_utils'
require 'sprockets/uri_utils'
require 'sprockets/utils'

module Sprockets
  # `Processing` is an internal mixin whose public methods are exposed on
  # the `Environment` and `CachedEnvironment` classes.
  module Processing
    include ProcessorUtils, URIUtils, Utils

    # Preprocessors are ran before Postprocessors and Engine
    # processors.
    def preprocessors
      config[:preprocessors]
    end
    alias_method :processors, :preprocessors

    # Postprocessors are ran after Preprocessors and Engine processors.
    def postprocessors
      config[:postprocessors]
    end

    # Registers a new Preprocessor `klass` for `mime_type`.
    #
    #     register_preprocessor 'text/css', Sprockets::DirectiveProcessor
    #
    # A block can be passed for to create a shorthand processor.
    #
    #     register_preprocessor 'text/css', :my_processor do |context, data|
    #       data.gsub(...)
    #     end
    #
    def register_preprocessor(*args, &block)
      register_config_processor(:preprocessors, *args, &block)
    end
    alias_method :register_processor, :register_preprocessor

    # Registers a new Postprocessor `klass` for `mime_type`.
    #
    #     register_postprocessor 'application/javascript', Sprockets::DirectiveProcessor
    #
    # A block can be passed for to create a shorthand processor.
    #
    #     register_postprocessor 'application/javascript', :my_processor do |context, data|
    #       data.gsub(...)
    #     end
    #
    def register_postprocessor(*args, &block)
      register_config_processor(:postprocessors, *args, &block)
    end

    # Remove Preprocessor `klass` for `mime_type`.
    #
    #     unregister_preprocessor 'text/css', Sprockets::DirectiveProcessor
    #
    def unregister_preprocessor(*args)
      unregister_config_processor(:preprocessors, *args)
    end
    alias_method :unregister_processor, :unregister_preprocessor

    # Remove Postprocessor `klass` for `mime_type`.
    #
    #     unregister_postprocessor 'text/css', Sprockets::DirectiveProcessor
    #
    def unregister_postprocessor(*args)
      unregister_config_processor(:postprocessors, *args)
    end

    # Bundle Processors are ran on concatenated assets rather than
    # individual files.
    def bundle_processors
      config[:bundle_processors]
    end

    # Registers a new Bundle Processor `klass` for `mime_type`.
    #
    #     register_bundle_processor  'application/javascript', Sprockets::DirectiveProcessor
    #
    # A block can be passed for to create a shorthand processor.
    #
    #     register_bundle_processor 'application/javascript', :my_processor do |context, data|
    #       data.gsub(...)
    #     end
    #
    def register_bundle_processor(*args, &block)
      register_config_processor(:bundle_processors, *args, &block)
    end

    # Remove Bundle Processor `klass` for `mime_type`.
    #
    #     unregister_bundle_processor 'application/javascript', Sprockets::DirectiveProcessor
    #
    def unregister_bundle_processor(*args)
      unregister_config_processor(:bundle_processors, *args)
    end

    # Public: Register bundle metadata reducer function.
    #
    # Examples
    #
    #   Sprockets.register_bundle_metadata_reducer 'application/javascript', :jshint_errors, [], :+
    #
    #   Sprockets.register_bundle_metadata_reducer 'text/css', :selector_count, 0 { |total, count|
    #     total + count
    #   }
    #
    # mime_type - String MIME Type. Use '*/*' applies to all types.
    # key       - Symbol metadata key
    # initial   - Initial memo to pass to the reduce funciton (default: nil)
    # block     - Proc accepting the memo accumulator and current value
    #
    # Returns nothing.
    def register_bundle_metadata_reducer(mime_type, key, *args, &block)
      case args.size
      when 0
        reducer = block
      when 1
        if block_given?
          initial = args[0]
          reducer = block
        else
          initial = nil
          reducer = args[0].to_proc
        end
      when 2
        initial = args[0]
        reducer = args[1].to_proc
      else
        raise ArgumentError, "wrong number of arguments (#{args.size} for 0..2)"
      end

      self.config = hash_reassoc(config, :bundle_reducers, mime_type) do |reducers|
        reducers.merge(key => [initial, reducer])
      end
    end

    # Internal: Gather all bundle reducer functions for MIME type.
    #
    # mime_type - String MIME type
    #
    # Returns an Array of [initial, reducer_proc] pairs.
    def load_bundle_reducers(mime_type)
      config[:bundle_reducers]['*/*'].merge(config[:bundle_reducers][mime_type])
    end

    # Internal: Run bundle reducers on set of Assets producing a reduced
    # metadata Hash.
    #
    # assets - Array of Assets
    # reducers - Array of [initial, reducer_proc] pairs
    #
    # Returns reduced asset metadata Hash.
    def process_bundle_reducers(assets, reducers)
      initial = {}
      reducers.each do |k, (v, _)|
        initial[k] = v if v
      end

      assets.reduce(initial) do |h, asset|
        reducers.each do |k, (_, block)|
          value = k == :data ? asset.source : asset.metadata[k]
          h[k]  = h.key?(k) ? block.call(h[k], value) : value
        end
        h
      end
    end

    protected
      def resolve_processors_cache_key_uri(uri)
        params = parse_uri_query_params(uri[11..-1])
        processors = processors_for(params[:type], params[:file_type], params[:skip_bundle])
        processors_cache_keys(processors)
      end

      def build_processors_uri(type, file_type, skip_bundle)
        query = encode_uri_query_params(
          type: type,
          file_type: file_type,
          skip_bundle: skip_bundle
        )
        "processors:#{query}"
      end

      def processors_for(type, file_type, skip_bundle)
        processors = []

        bundled_processors = skip_bundle ? [] : config[:bundle_processors][type]

        if bundled_processors.any?
          processors.concat bundled_processors
        else
          processors.concat config[:postprocessors][type]
          if type != file_type && processor = config[:transformers][file_type][type]
            processors << processor
          end
          processors.concat config[:preprocessors][file_type]
        end

        if processors.any? || mime_type_charset_detecter(type)
          processors << FileReader
        end

        processors
      end

    private
      def register_config_processor(type, mime_type, processor = nil, &block)
        processor ||= block

        self.config = hash_reassoc(config, type, mime_type) do |processors|
          processors.unshift(processor)
          processors
        end

        compute_transformers!
      end

      def unregister_config_processor(type, mime_type, proccessor)
        self.config = hash_reassoc(config, type, mime_type) do |processors|
          processors.delete(proccessor)
          processors
        end

        compute_transformers!
      end
  end
end
