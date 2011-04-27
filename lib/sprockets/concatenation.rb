require 'sprockets/errors'
require 'sprockets/engine_pathname'
require 'digest/md5'
require 'pathname'
require 'rack/utils'
require 'set'
require 'time'

module Sprockets
  class Concatenation
    attr_reader :environment, :pathname
    attr_reader :content_type, :format_extension
    attr_reader :paths
    attr_accessor :mtime

    def initialize(environment, pathname)
      @environment = environment
      @pathname    = Pathname.new(pathname)

      @content_type     = nil
      @format_extension = nil

      @paths  = Set.new
      @source = ""
      @mtime  = Time.at(0)
    end

    def digest
      Digest::MD5.hexdigest(to_s)
    end

    def length
      Rack::Utils.bytesize(to_s)
    end

    def to_s
      @source
    end

    def <<(str)
      @source << str.to_s
      self
    end

    def post_process!
      @source = evaluate(environment.engines.concatenation_processors, pathname, @source)
      nil
    end

    def depend(pathname)
      pathname = Pathname.new(pathname)

      if pathname.mtime > mtime
        self.mtime = pathname.mtime
      end

      paths << pathname.to_s

      pathname
    end

    def requirable?(pathname)
      content_type.nil? || content_type == EnginePathname.new(pathname, environment.engines).content_type
    end

    def require(pathname)
      pathname        = Pathname.new(pathname)
      engine_pathname = EnginePathname.new(pathname, environment.engines)

      @content_type     ||= engine_pathname.content_type
      @format_extension ||= engine_pathname.format_extension

      if requirable?(pathname)
        unless paths.include?(pathname.to_s)
          depend pathname
          self << process(pathname)
        end
      else
        raise ContentTypeMismatch, "#{pathname} is " +
          "'#{ EnginePathname.new(pathname, environment.engines).format_extension}', " +
          "not '#{format_extension}'"
      end

      pathname
    end

    def process(pathname)
      pathname        = Pathname.new(pathname)
      engine_pathname = EnginePathname.new(pathname, environment.engines)
      engines         = environment.engines.pre_processors +
                          engine_pathname.engines.reverse +
                          environment.engines.post_processors

      evaluate(engines, pathname, pathname.read)
    end

    private
      def evaluate(engines, pathname, data)
        scope    = environment.context.new(environment, self, pathname)
        locals   = {}

        engines.inject(data) do |result, engine|
          template = engine.new(pathname.to_s) { result }
          template.render(scope, locals)
        end
      end
  end
end
