require 'coffee_script'
require 'json'
require 'source_map'

module Sprockets
  # Template engine class for the CoffeeScript compiler.
  # Depends on the `coffee-script` and `coffee-script-source` gems.
  #
  # For more infomation see:
  #
  #   https://github.com/josh/ruby-coffee-script
  #
  module CoffeeScriptTemplate
    VERSION = '2'
    SOURCE_VERSION = ::CoffeeScript::Source.version

    def self.call(input)
      data = input[:data]
      key  = ['CoffeeScriptTemplate', SOURCE_VERSION, VERSION, data]

      result = input[:cache].fetch(key) do
        ::CoffeeScript.compile(data, sourceMap: true)
      end

      if input[:map]
        map = input[:map] | SourceMap::Map.from_json(result['v3SourceMap'])
        { data: result['js'],
          map: map }
      else
        result['js']
      end
    end
  end
end
