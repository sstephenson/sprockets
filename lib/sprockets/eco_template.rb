require 'eco'
require 'thread'

module Sprockets
  # Template engine class for the Eco compiler. Depends on the `eco` gem.
  #
  # For more infomation see:
  #
  #   https://github.com/sstephenson/ruby-eco
  #   https://github.com/sstephenson/eco
  #
  module EcoTemplate
    VERSION = '1'
    LOCK = Mutex.new

    # Compile template data with Eco compiler.
    #
    # Returns a JS function definition String. The result should be
    # assigned to a JS variable.
    #
    #     # => "function(...) {...}"
    #
    def self.call(input)
      data = input[:data]
      key  = ['EcoTemplate', ::Eco::Source::VERSION, VERSION, data]
      input[:cache].fetch(key) do
        begin
          LOCK.lock
          ::Eco.compile(data)
        ensure
          LOCK.unlock
        end
      end
    end
  end
end
