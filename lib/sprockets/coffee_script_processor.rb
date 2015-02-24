require 'source_map'

module Sprockets
  # Processor engine class for the CoffeeScript compiler.
  # Depends on the `coffee-script` and `coffee-script-source` gems.
  #
  # For more infomation see:
  #
  #   https://github.com/josh/ruby-coffee-script
  #
  module CoffeeScriptProcessor
    VERSION = '2'

    def self.cache_key
      @cache_key ||= [name, Autoload::CoffeeScript::Source.version, VERSION].freeze
    end

    def self.call(input)
      data = input[:data]

      result = input[:cache].fetch(self.cache_key + [data]) do
        Autoload::CoffeeScript.compile(data, sourceMap: true, sourceFiles: [input[:source_path]])
      end

      map = input[:metadata][:map] | SourceMap::Map.from_json(result['v3SourceMap'])
      { data: result['js'], map: map }
    end
  end
end
