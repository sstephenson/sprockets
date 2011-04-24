require 'tilt'

module Sprockets
  module TemplateMappings
    # Make all methods defined in TemplateMappings class level
    extend self

    # A hash to hold mappings of extensions to engines that handle them e.g. {'haml' => Haml, 'erb' => Erb}
    MAPPINGS = {}

    # Map an extension with a processing engine
    def register(ext, klass)
      ext = ext.to_s.sub(/^\./, '').downcase
      MAPPINGS[ext] = klass
    end

    # Lookup the corresponding engine for a given extension. If Sprockets doesn't have a mapping, try Tilt
    def lookup_engine(ext)
      ext = ext.to_s.sub(/^\./, '').downcase
      MAPPINGS[ext] || Tilt[ext]
    end
  end
end
