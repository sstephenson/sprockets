require 'coffee_script'
require 'thread'

module Sprockets
  # Template engine class for the CoffeeScript compiler.
  # Depends on the `coffee-script` and `coffee-script-source` gems.
  #
  # For more infomation see:
  #
  #   https://github.com/josh/ruby-coffee-script
  #
  module CoffeeScriptTemplate
    VERSION = '1'
    SOURCE_VERSION = ::CoffeeScript::Source.version
    LOCK = Mutex.new

    def self.call(input)
      data = input[:data]
      key  = ['CoffeeScriptTemplate', SOURCE_VERSION, VERSION, data]
      input[:cache].fetch(key) do
        begin
          LOCK.lock
          ::CoffeeScript.compile(data)
        ensure
          LOCK.unlock
        end
      end
    end
  end
end
