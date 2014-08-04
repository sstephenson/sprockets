require 'uglifier'
require 'thread'

module Sprockets
  # Public: Uglifier/Uglify compressor.
  #
  # To accept the default options
  #
  #     environment.register_bundle_processor 'application/javascript',
  #       Sprockets::UglifierCompressor
  #
  # Or to pass options to the Uglifier class.
  #
  #     environment.register_bundle_processor 'application/javascript',
  #       Sprockets::UglifierCompressor.new(comments: :copyright)
  #
  class UglifierCompressor
    VERSION = '1'
    LOCK = Mutex.new

    def self.call(*args)
      new.call(*args)
    end

    def initialize(options = {})
      # Feature detect Uglifier 2.0 option support
      if Uglifier::DEFAULTS[:copyright]
        # Uglifier < 2.x
        options[:copyright] ||= false
      else
        # Uglifier >= 2.x
        options[:copyright] ||= :none
      end

      @uglifier = ::Uglifier.new(options)

      @cache_key = [
        'UglifierCompressor',
        ::Uglifier::VERSION,
        VERSION,
        options
      ]
    end

    def call(input)
      data = input[:data]
      input[:cache].fetch(@cache_key + [data]) do
        begin
          LOCK.lock
          @uglifier.compile(data)
        ensure
          LOCK.unlock
        end
      end
    end
  end
end
