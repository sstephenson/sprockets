# Define some basic Sprockets error classes
module Sprockets
  class Error       < StandardError; end
  class ArgumentError       < Error; end
  class FileNotFound        < Error; end
  class ContentTypeMismatch < Error; end
end
