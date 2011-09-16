require 'pathname'
require 'tilt'

module Sprockets
  
  class SassImporter
    GLOB = /\*|\[.+\]/
    PARTIAL = /^_/
    HAS_EXTENSION = /\.css(.s[ac]ss)?$/

    SASS_EXTENSIONS = {
      ".css.sass" => :sass,
      ".css.scss" => :scss,
      ".sass" => :sass,
      ".scss" => :scss
    }
    attr_reader :context

    def initialize(context)
      @context = context
      @resolver = SassResolver.new(context)
    end

    def sass_file?(filename)
      filename = filename.to_s
      SASS_EXTENSIONS.keys.any?{|ext| filename[ext]}
    end

    def syntax(filename)
      filename = filename.to_s
      SASS_EXTENSIONS.each {|ext, syntax| return syntax if filename[(ext.size+2)..-1][ext]}
      nil
    end

    def resolve(name, base_pathname = nil)
      name = Pathname.new(name)
      if base_pathname && base_pathname.to_s.size > 0
        root = Pathname.new(context.root_path)
        name = base_pathname.relative_path_from(root).join(name)
      end
      partial_name = name.dirname.join("_#{name.basename}")
      @resolver.resolve(name) || @resolver.resolve(partial_name)
    end

    def find_relative(name, base, options)
      base_pathname = Pathname.new(base)
      if name =~ GLOB
        glob_imports(name, base_pathname, options)
      elsif pathname = resolve(name, base_pathname.dirname)
        context.depend_on(pathname)
        if sass_file?(pathname)
          Sass::Engine.new(pathname.read, options.merge(:filename => pathname.to_s, :importer => self, :syntax => syntax(pathname)))
        else
          Sass::Engine.new(@resolver.process(pathname), options.merge(:filename => pathname.to_s, :importer => self, :syntax => :scss))
        end
      else
        nil
      end
    end

    def find(name, options)
      if name =~ GLOB
        nil # globs must be relative
      elsif pathname = resolve(name)
        context.depend_on(pathname)
        if sass_file?(pathname)
          Sass::Engine.new(pathname.read, options.merge(:filename => pathname.to_s, :importer => self, :syntax => syntax(pathname)))
        else
          Sass::Engine.new(@resolver.process(pathname), options.merge(:filename => pathname.to_s, :importer => self, :syntax => :scss))
        end
      else
        nil
      end
    end

    def each_globbed_file(glob, base_pathname, options)
      Dir["#{base_pathname}/#{glob}"].sort.each do |filename|
        next if filename == options[:filename]
        yield filename if File.directory?(filename) || context.asset_requirable?(filename)
      end
    end

    def glob_imports(glob, base_pathname, options)
      contents = ""
      each_globbed_file(glob, base_pathname.dirname, options) do |filename|
        if File.directory?(filename)
          context.depend_on(filename)
        elsif context.asset_requirable?(filename)
          context.depend_on(filename)
          contents << "@import #{Pathname.new(filename).relative_path_from(base_pathname.dirname).to_s.inspect};\n"
        end
      end
      return nil if contents.empty?
      Sass::Engine.new(contents, options.merge(
        :filename => base_pathname.to_s,
        :importer => self,
        :syntax => :scss
      ))
    end

    def mtime(name, options)
      if name =~ GLOB && options[:filename]
        mtime = nil
        each_globbed_file(name, Pathname.new(options[:filename]).dirname, options) do |p|
          mtime ||= File.mtime(p)
          mtime = [mtime, File.mtime(p)].max
        end
        mtime
      elsif pathname = resolve(name)
        pathname.mtime
      end
    end

    def key(name, options)
      ["Sprockets:" + File.dirname(File.expand_path(name)), File.basename(name)]
    end

    def to_s
      "Sprockets::SassImporter(#{context.pathname})"
    end

  end

  class SassResolver

    attr_accessor :context

    def initialize(context)
      @context = context
    end

    def resolve(path, content_type = :self)
      options = {}
      options[:content_type] = content_type unless content_type.nil?
      context.resolve(path, options)
    rescue Sprockets::FileNotFound, Sprockets::ContentTypeMismatch
      nil
    end

    def public_path(path, scope)
      context.asset_paths.compute_public_path(path, scope)
    end

    def process(path)
      context.environment[path].to_s
    end
  end

  class SassTemplate < Tilt::SassTemplate
    self.default_mime_type = 'text/css'

    def self.engine_initialized?
      defined?(::Sass::Engine)
    end

    def initialize_engine
      require_template_library 'sass'
    end

    def syntax
      :sass
    end

    def global_sass_options(scope)
      scope.environment.context_class.respond_to?(:sass_config) and scope.environment.context_class.sass_config
    end

    def sass_options(scope)
      importer = self.importer(scope)
      options = global_sass_options(scope) || {}
      load_paths = (options[:load_paths] || []).dup
      load_paths.unshift(importer)
      options.merge(
        :filename => eval_file,
        :line => line,
        :syntax => syntax,
        :importer => importer,
        :load_paths => load_paths,
        :custom => {
          :resolver => SassResolver.new(scope)
        }
      )
    end

    def importer(scope)
      SassImporter.new(scope)
    end

    def prepare
    end

    def evaluate(scope, locals, &block)
      Sass::Engine.new(data, sass_options(scope)).render
    end
  end

  class ScssTemplate < SassTemplate
    self.default_mime_type = 'text/css'

    def syntax
      :scss
    end
  end
end
