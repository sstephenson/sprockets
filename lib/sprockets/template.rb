module Sprockets
  class Template
    attr_reader :data

    def initialize(file, &block)
      @data = block.call
    end
  end
end
