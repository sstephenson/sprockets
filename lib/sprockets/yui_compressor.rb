require 'thread'
require 'yui/compressor'

module Sprockets
  # Public: YUI compressor.
  #
  # To accept the default options
  #
  #     environment.register_bundle_processor 'application/javascript',
  #       Sprockets::YUICompressor
  #
  # Or to pass options to the YUI::JavaScriptCompressor class.
  #
  #     environment.register_bundle_processor 'application/javascript',
  #       Sprockets::YUICompressor.new(munge: true)
  #
  class YUICompressor
    VERSION = '1'
    LOCK = Mutex.new

    def self.call(*args)
      new.call(*args)
    end

    def initialize(options = {})
      @options = options
      @cache_key = [
        'YUICompressor',
        ::YUI::Compressor::VERSION,
        VERSION,
        options
      ]
    end

    def call(input)
      data = input[:data]

      case input[:content_type]
      when 'application/javascript'
        key = @cache_key + [input[:content_type], input[:data]]
        input[:cache].fetch(key) do
          begin
            LOCK.lock
            ::YUI::JavaScriptCompressor.new(@options).compress(data)
          ensure
            LOCK.unlock
          end
        end
      when 'text/css'
        key = @cache_key + [input[:content_type], input[:data]]
        input[:cache].fetch(key) do
          begin
            LOCK.lock
            ::YUI::CssCompressor.new(@options).compress(data)
          ensure
            LOCK.unlock
          end
        end
      else
        data
      end
    end
  end
end
