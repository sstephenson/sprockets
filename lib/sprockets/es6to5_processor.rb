module Sprockets
  class ES6to5Processor
    VERSION = '1'

    def self.instance
      @instance ||= new
    end

    def self.call(input)
      instance.call(input)
    end

    def initialize(options = {})
      @options = options.merge({
        'blacklist' => (options['blacklist'] || []) + ['useStrict'],
        'sourceMap' => true
      }).freeze

      @cache_key = [
        self.class.name,
        Autoload::ES6to5.version,
        VERSION,
        @options
      ].freeze
    end

    def call(input)
      data = input[:data]

      result = input[:cache].fetch(@cache_key + [data]) do
        Autoload::ES6to5.transform(data, @options)
      end

      result['code']
    end
  end
end
