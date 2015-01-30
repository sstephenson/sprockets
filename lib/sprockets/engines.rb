require 'sprockets/utils'

module Sprockets
  # `Engines` provides a global and `Environment` instance registry.
  #
  # An engine is a type of processor that is bound to a filename
  # extension. `application.coffee` indicates that the
  # `CoffeeScriptProcesor` engine will be ran on the file.
  #
  # Extensions can be stacked and will be evaulated from right to
  # left. `application.coffee.erb` will first run `ERBProcessor`
  # then `CoffeeScriptProcessor`.
  #
  # All `Engine`s must follow the `Processor` interface.
  #
  # Its recommended that you register engine changes on your local
  # `Environment` instance.
  #
  #     environment.register_engine '.foo', FooProcessor
  #
  # The global registry is exposed for plugins to register themselves.
  #
  #     Sprockets.register_engine '.sass', SassProcessor
  #
  module Engines
    include Utils

    # Returns a `Hash` of `Engine`s registered on the `Environment`.
    # If an `ext` argument is supplied, the `Engine` associated with
    # that extension will be returned.
    #
    #     environment.engines
    #     # => {".coffee" => CoffeeScriptProcessor, ".sass" => SassProcessor, ...}
    #
    def engines
      config[:engines]
    end

    # Internal: Returns a `Hash` of engine extensions to mime types.
    #
    # # => { '.coffee' => 'application/javascript' }
    def engine_mime_types
      config[:engine_mime_types]
    end

    # Registers a new Engine `klass` for `ext`. If the `ext` already
    # has an engine registered, it will be overridden.
    #
    #     environment.register_engine '.coffee', CoffeeScriptProcessor
    #
    def register_engine(ext, klass, options = {})
      self.config = hash_reassoc(config, :engines) do |engines|
        engines.merge(ext => klass)
      end
      if options[:mime_type]
        self.config = hash_reassoc(config, :engine_mime_types) do |mime_types|
          mime_types.merge(ext.to_s => options[:mime_type])
        end
      end

      self.config = hash_reassoc(config, :_extnames) do
        compute_extname_map
      end
    end
  end
end
