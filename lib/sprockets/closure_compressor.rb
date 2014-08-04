require 'closure-compiler'
require 'thread'

module Sprockets
  # Public: Closure Compiler minifier.
  #
  # To accept the default options
  #
  #     environment.register_bundle_processor 'application/javascript',
  #       Sprockets::ClosureCompressor
  #
  # Or to pass options to the Closure::Compiler class.
  #
  #     environment.register_bundle_processor 'application/javascript',
  #       Sprockets::ClosureCompressor.new({ ... })
  #
  class ClosureCompressor
    VERSION = '1'
    LOCK = Mutex.new

    def self.call(*args)
      new.call(*args)
    end

    def initialize(options = {})
      @compiler = ::Closure::Compiler.new(options)
      @cache_key = [
        'ClosureCompressor',
        ::Closure::VERSION,
        ::Closure::COMPILER_VERSION,
        VERSION,
        options
      ]
    end

    def call(input)
      input[:cache].fetch(@cache_key + [input[:data]]) do
        begin
          LOCK.lock
          @compiler.compile(input[:data])
        ensure
          LOCK.unlock
        end
      end
    end
  end
end
