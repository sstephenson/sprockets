require 'erb'

module Sprockets
  class ERBTemplate
    def self.call(input)
      new.call(input)
    end

    def initialize(&block)
      @block = block
    end

    def call(input)
      engine = ::ERB.new(input[:data], nil, '<>')
      context = input[:environment].context_class.new(input)
      klass = (class << context; self; end)
      klass.class_eval(&@block) if @block
      engine.def_method(klass, :_evaluate_template, input[:filename])
      data = context._evaluate_template
      context.metadata.merge(data: data)
    end
  end
end
