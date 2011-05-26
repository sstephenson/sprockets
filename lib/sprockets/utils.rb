module Sprockets
  module Utils
    def self.normalize_extension(extension)
      extension = extension.to_s
      if extension[/^\./]
        extension
      else
        ".#{extension}"
      end
    end
  end
end
