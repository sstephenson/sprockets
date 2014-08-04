require 'ejs'
require 'thread'

module Sprockets
  # Template engine class for the EJS compiler. Depends on the `ejs` gem.
  #
  # For more infomation see:
  #
  #   https://github.com/sstephenson/ruby-ejs
  #
  module EjsTemplate
    VERSION = '1'
    LOCK = Mutex.new

    # Compile template data with EJS compiler.
    #
    # Returns a JS function definition String. The result should be
    # assigned to a JS variable.
    #
    #     # => "function(obj){...}"
    #
    def self.call(input)
      data = input[:data]
      key  = ['EjsTemplate', VERSION, data]
      input[:cache].fetch(key) do
        begin
          LOCK.lock
          ::EJS.compile(data)
        ensure
          LOCK.unlock
        end
      end
    end
  end
end
