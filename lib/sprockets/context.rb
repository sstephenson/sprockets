require 'sprockets/errors'
require 'pathname'
require 'set'

#### Sprockets::Context
#
# The context class keeps track of an environment, basepath, and the logical path for a pathname
# TODO Fill in with better explanation
module Sprockets
  class Context
    attr_reader :environment, :pathname
    attr_reader :_required_paths, :_dependency_paths
    attr_writer :__LINE__

    def initialize(environment, logical_path, pathname)
      @environment  = environment
      @logical_path = logical_path
      @pathname     = pathname
      @__LINE__     = nil

      @_required_paths   = []
      @_dependency_paths = Set.new
    end

    def root_path
      environment.paths.detect { |path| pathname.to_s[path] }
    end

    def logical_path
      @logical_path[/^([^.]+)/, 0]
    end

    def content_type
      environment.content_type_of(pathname)
    end

    def resolve(path, options = {}, &block)
      pathname   = Pathname.new(path)
      attributes = environment.attributes_for(pathname)

      if pathname.absolute?
        pathname

      elsif content_type = options[:content_type]
        content_type = self.content_type if content_type == :self

        if attributes.format_extension
          if content_type != attributes.content_type
            raise ContentTypeMismatch, "#{path} is " +
              "'#{attributes.content_type}', not '#{content_type}'"
          end
        end

        resolve(path) do |candidate|
          if self.content_type == environment.content_type_of(candidate)
            return candidate
          end
        end

        raise FileNotFound, "couldn't find file '#{path}'"
      else
        environment.resolve(path, :base_path => self.pathname.dirname, &block)
      end
    end

    def depend_on(path)
      @_dependency_paths << resolve(path).to_s
    end

    def evaluate(filename, options = {})
      start_time = Time.now.to_f
      pathname   = resolve(filename)
      attributes = environment.attributes_for(pathname)

      data    = options[:data] || pathname.read
      result  = strip_bom(data)
      engines = options[:engines] || environment.processors(content_type) +
                          attributes.engines.reverse

      engines.each do |engine|
        begin
          template = engine.new(pathname.to_s) { result }
          result = template.render(self, {})
        rescue Exception => e
          annotate_exception! e
          raise
        end
      end

      elapsed_time = ((Time.now.to_f - start_time) * 1000).to_i
      logger.info "Compiled #{attributes.pretty_path}  (#{elapsed_time}ms)  (pid #{Process.pid})"

      result
    end

    def asset_requirable?(path)
      pathname = resolve(path)
      content_type = environment.content_type_of(pathname)
      pathname.file? && (self.content_type.nil? || self.content_type == content_type)
    end

    def require_asset(path)
      pathname = resolve(path, :content_type => :self)

      unless @_required_paths.include?(pathname.to_s)
        @_dependency_paths << pathname.to_s
        @_required_paths << pathname.to_s
      end

      pathname
    end

    private
      def annotate_exception!(exception)
        location = pathname.to_s
        location << ":#{@__LINE__}" if @__LINE__

        exception.extend(Sprockets::EngineError)
        exception.sprockets_annotation = "  (in #{location})"
      end

      def logger
        environment.logger
      end

      def strip_bom(str)
        if (str[0..2] == "\xef\xbb\xbf")
          str[3..-1]
        else
          str
        end
      end
  end
end
