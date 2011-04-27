require 'sprockets/engine_pathname'
require 'pathname'
require 'shellwords'
require 'tilt'
require 'yaml'

module Sprockets
  class DirectiveProcessor < Tilt::Template
    attr_reader :pathname

    def prepare
      @pathname = Pathname.new(file)

      @included_pathnames = []
      @compat             = false
    end

    def evaluate(context, locals, &block)
      @context     = context
      @environment = context.sprockets_environment

      process_directives
      process_source
    end

    protected
      class Parser
        HEADER_PATTERN = /
          \A \s* (
            (\/\* ([\s\S]*?) \*\/) |
            (\#\#\# ([\s\S]*?) \#\#\#) |
            (\/\/ ([^\n]*) \n?)+ |
            (\# ([^\n]*) \n?)+
          )
        /mx

        DIRECTIVE_PATTERN = /
          ^ [\W]* = \s* (\w+.*?) (\*\/)? $
        /x

        attr_reader :source, :header, :body

        def initialize(source)
          @source = source
          @header = @source[HEADER_PATTERN, 0] || ""
          @body   = $' || @source
          @body  += "\n" if @body != "" && @body !~ /\n\Z/m
        end

        def header_lines
          @header_lines ||= header.split("\n")
        end

        def processed_header
          header_lines.reject do |line|
            extract_directive(line)
          end.join("\n")
        end

        def processed_source
          @processed_source ||= processed_header + body
        end

        def directives
          @directives ||= header_lines.map do |line|
            if directive = extract_directive(line)
              Shellwords.shellwords(directive)
            end
          end.compact
        end

        def extract_directive(line)
          line[DIRECTIVE_PATTERN, 1]
        end
      end

      attr_reader :included_pathnames
      attr_reader :context

      def process_directives
        @directive_parser = Parser.new(data)

        @directive_parser.directives.each do |name, *args|
          send("process_#{name}_directive", *args)
        end
      end

      def process_source
        result = ""

        unless @directive_parser.processed_header.empty?
          result << @directive_parser.processed_header << "\n"
        end

        included_pathnames.each { |p| result << context.sprockets_process(p) }

        result << @directive_parser.body

        # LEGACY
        if compat? && constants.any?
          result.gsub!(/<%=(.*?)%>/) { constants[$1.strip] }
        end

        result
      end

      def compat?
        @compat
      end

      # LEGACY
      def constants
        if compat?
          path = File.join(context.root_path, "constants.yml")
          File.exist?(path) ? YAML.load_file(path) : {}
        else
        {}
        end
      end

      def process_compat_directive
        @compat = true
      end

      def process_depend_directive(path)
        context.sprockets_depend(context.sprockets_resolve(path))
      end

      def process_include_directive(path)
        included_pathnames << context.sprockets_resolve(path)
      end

      def process_require_directive(path)
        if @compat
          if path =~ /<([^>]+)>/
            path = $1
          else
            path = "./#{path}" unless relative?(path)
          end
        end

        context.sprockets_require(path)
      end

      def process_require_directory_directive(path = ".")
        if relative?(path)
          root = base_path.join(path).expand_path

          context.sprockets_depend(root)

          Dir["#{root}/*"].sort.each do |filename|
            pathname = Pathname.new(filename)
            if pathname.file? &&
                EnginePathname.new(pathname, @environment.engines).content_type == EnginePathname.new(self.pathname, @environment.engines).content_type
              if pathname.file?
                context.sprockets_require(pathname)
              else
                context.sprockets_depend(pathname)
              end
            end
          end
        else
          raise ArgumentError, "require_directory argument must be a relative path"
        end
      end

      def process_require_tree_directive(path = ".")
        if relative?(path)
          root = base_path.join(path).expand_path

          context.sprockets_depend(root)

          each_pathname_in_tree(path) do |pathname|
            if pathname.file?
              context.sprockets_require(pathname)
            else
              context.sprockets_depend(pathname)
            end
          end
        else
          raise ArgumentError, "require_tree argument must be a relative path"
        end
      end

      def process_provide_directive(path)
        # ignore
      end

    private
      def each_pathname_in_tree(path)
        Dir["#{base_path.join(path)}/**/*"].sort.each do |filename|
          pathname = Pathname.new(filename)

          if pathname.directory?
            yield pathname
          elsif pathname.file? &&
              EnginePathname.new(pathname, @environment.engines).content_type == EnginePathname.new(self.pathname, @environment.engines).content_type
            yield pathname
          end
        end
      end

      def relative?(path)
        path =~ /^\.($|\.?\/)/
      end

      def base_path
        self.pathname.dirname
      end
  end
end
