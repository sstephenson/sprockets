# Define some basic Sprockets error classes
module Sprockets
  class Error           < StandardError; end
  class ArgumentError           < Error; end
  class CircularDependencyError < Error; end
  class ContentTypeMismatch     < Error; end
  class FileNotFound            < Error; end
end
