require 'sprockets/ejs_template'
require 'sprockets/jst_processor'
require 'sprockets/utils'
require 'tilt'

module Sprockets
  module Engines
    def engines(ext = nil)
      if ext
        ext = Sprockets::Utils.normalize_extension(ext)
        @engines[ext]
      else
        @engines.dup
      end
    end

    def engine_extensions
      @engines.keys
    end

    def register_engine(ext, klass)
      ext = Sprockets::Utils.normalize_extension(ext)
      @engines ||= {}
      @engines[ext] = klass
    end
  end

  extend Engines

  register_engine '.coffee', Tilt::CoffeeScriptTemplate
  register_engine '.erb',    Tilt::ERBTemplate
  register_engine '.ejs',    EjsTemplate
  register_engine '.jst',    JstProcessor
  register_engine '.less',   Tilt::LessTemplate
  register_engine '.sass',   Tilt::SassTemplate
  register_engine '.scss',   Tilt::ScssTemplate
  register_engine '.str',    Tilt::StringTemplate
end
