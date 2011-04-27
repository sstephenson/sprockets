require 'pathname'

module Sprockets
  # TODO: Junk drawer
  module Utils
    def path_fingerprint(path)
      pathname = Pathname.new(path)
      extensions = pathname.basename.to_s.scan(/\.[^.]+/).join
      pathname.basename(extensions).to_s =~ /-([0-9a-f]{7,40})$/ ? $1 : nil
    end
    module_function :path_fingerprint

    def path_with_fingerprint(path, digest)
      pathname = Pathname.new(path)
      extensions = pathname.basename.to_s.scan(/\.[^.]+/).join

      if pathname.basename(extensions).to_s =~ /-([0-9a-f]{7,40})$/
        path.sub($1, digest)
      else
        basename = "#{pathname.basename(extensions)}-#{digest}#{extensions}"
        pathname.dirname.to_s == '.' ? basename : pathname.dirname.join(basename).to_s
      end
    end
    module_function :path_with_fingerprint
  end
end
