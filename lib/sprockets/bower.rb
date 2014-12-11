require 'json'

module Sprockets
  module Bower
    # Internal: All supported bower.json files.
    #
    # https://github.com/bower/json/blob/0.4.0/lib/json.js#L7
    POSSIBLE_BOWER_JSONS = ['bower.json', 'component.json', '.bower.json']

    # Internal: Local .bowerrc filenames
    POSSIBLE_BOWER_RCS = ['.bowerrc']

    # Internal: Override resolve_alternates to install bower.json behavior.
    #
    # load_path    - String environment path
    # logical_path - String path relative to base
    #
    # Returns nothing.
    def resolve_alternates(load_path, logical_path, &block)
      super

      # bower.json can only be nested one level deep
      if !logical_path.index('/')
        dirname = File.join(load_path, logical_path)
        stat    = self.stat(dirname)

        if stat && stat.directory?
          filenames = POSSIBLE_BOWER_JSONS.map { |basename| File.join(dirname, basename) }
          filename  = filenames.detect { |fn| self.file?(fn) }

          if filename
            read_bower_main(dirname, filename, &block)
          end
        end
      end

      nil
    end

    # Internal: Read bower.json's main directive.
    #
    # dirname  - String path to component directory.
    # filename - String path to bower.json.
    #
    # Returns nothing.
    def read_bower_main(dirname, filename)
      bower = JSON.parse(File.read(filename), create_additions: false)

      case bower['main']
      when String
        yield File.expand_path(bower['main'], dirname)
      when Array
        bower['main'].each do |name|
          yield File.expand_path(name, dirname)
        end
      end
    end

    # Enable .bowerrc reading by checking for possible .bowerrc files.
    #
    # Returns nothing.

    def use_bowerrc
      POSSIBLE_BOWER_RCS.each { |fn| read_bowerrc(fn) if self.file?(fn) }
    end

    # Internal: Read bower configuration file to find the bower path.
    #
    # filename - String path to .bowerrc
    #
    # Returns nothing.

    def read_bowerrc(filename)
      bower = JSON.parse(File.read(filename))
      directory = bower['directory']
      stat = self.stat(directory)

      if stat && stat.directory?
        prepend_path(directory)
      end
    end
  end
end
