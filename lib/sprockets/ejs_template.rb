module Sprockets
  # Template engine class for the EJS compiler. Depends on the `ejs` gem.
  #
  # For more infomation see:
  #
  #   https://github.com/sstephenson/ruby-ejs
  #
  class EjsTemplate < Template
    # Compile template data with EJS compiler.
    #
    # Returns a JS function definition String. The result should be
    # assigned to a JS variable.
    #
    #     # => "function(obj){...}"
    #
    def render(context)
      require 'ejs' unless defined? ::EJS
      EJS.compile(data)
    end
  end
end
