require 'optparse'
require 'ostruct'
require 'pathname'
require 'set'
require 'fileutils'
require 'yaml'

module Sprockets
  class CLI
    SPROCKETS_FILE = '.sprocksrc'

    attr_accessor :local_options, :global_options, :paths

    def compile
      env = Sprockets::Environment.new(@root)
      (@paths + (@global_options[:paths] || Set.new)).each {|p| env.append_path(p)}

      assets = local_options[:assets].map {|a| realpath(a).to_s}
      filter = Proc.new do |asset|
        assets.any? {|a| asset.pathname.to_s.start_with?(a)}
      end

      options = {
          :manifest => local_options[:manifest] || global_options[:manifest],
          :manifest_path => local_options[:manifest_path],
          :digest => local_options[:digest] || global_options[:digest],
          :gzip => local_options[:gzip] || global_options[:gzip]
      }

      compiler = Sprockets::Compiler.new(env, realpath(@local_options[:target]), [filter], options)
      compiler.compile
    end

    def initialize(*args)
      @assets = Set.new
      @local_paths = Set.new
      @global_options = load_global_options
      input = parse_input(args)
      @root = input.delete(:root)
      @save = input.delete(:save)
      @local_options = load_local_options(@root)
      @local_options = merge_options(load_local_options(@root), input)
      @local_options.freeze #to preserve exact user input
    end

    def merge_options(target, source)
      {
          :target => source[:target] || target[:target],
          :paths => (target[:paths] || Set.new).merge((source[:paths] || Set.new)),
          :assets => (target[:assets] || Set.new).merge((source[:assets] || Set.new)),
          :digest => (source[:digest].nil? ? target[:digest] : source[:digest]),
          :manifest => (source[:manifest].nil? ? target[:manifest] : source[:manifest]),
          :manifest_path => (source[:manifest_path] || target[:manifest_path]),
          :gzip => (source[:gzip].nil? ? target[:gzip] : source[:gzip])
      }
    end

    def puts_error(message)
      puts "\e[31msprocketize: #{message}\e[0m"
    end

    def run
      if @local_options[:target].to_s.length == 0
        puts_error "no output directory provided"
        show_usage
      elsif @local_options[:assets].length == 0
        puts_error "no assets provided"
        show_usage
      else
        @paths = Set.new
        @local_options[:assets].each do |a|
          a = realpath(a)
          @paths << (a.file? ? a.dirname : a)
        end
        @local_options[:paths].each {|p| @paths << realpath(p)}

        compile
        save_local_options if @save
      end
    rescue OptionParser::InvalidOption => e
      puts_error e.message
      show_usage
    rescue Sprockets::FileNotFound => e
      puts_error e.message
    end

    def show_usage
      puts parser
    end

    def show_version
      puts ::Sprockets::VERSION
    end

    private

    def default_global_options
      {:paths => Set.new}
    end

    def exit_if_non_existent(path)
      return if File.exists?(path)
      puts "No such file or directory #{path}"
      exit
    end

    def parse_input(args)
      input = {
        :root => Pathname.new('.'),
        :paths => Set.new,
        :assets => []
      }

      parser = OptionParser.new do |opts|
        opts.banner = "Usage: sprocketize [options] output_directory filename [filename ...]"

        opts.on("-a DIRECTORY", "--asset-root=DIRECTORY", "Assets root path.") do |dir|
          exit_if_non_existent(dir)
          input[:root] = realpath(dir)
        end

        opts.on("-I DIRECTORY", "--include-dir=DIRECTORY", "Adds the directory to the Sprockets load path.") do |dir|
          exit_if_non_existent(dir)
          input[:paths] << dir
        end

        opts.on("-d", "--digest", "Incorporates a MD5 digest into all filenames.") do
          input[:digest] = true
        end

        opts.on("-m [DIRECTORY]", "--manifest [=DIRECTORY]", "Writes a manifest for the assets. If no directory is specified the manifest will be written to the output directory.") do |dir|
          input[:manifest] = true
          input[:manifest_path] = dir
        end

        opts.on("-g", "--gzip", "Also create a compressed version of all Stylesheets and Javascripts.") do |dir|
          input[:gzip] = true
        end

        opts.on("-s", "--save", "Add given parameters to #{SPROCKETS_FILE}") do |dir|
          input[:save] = true
        end

        opts.on_tail("-h", "--help", "Show this help message.") do
          show_usage
          exit
        end

        opts.on_tail("-v", "--version", "Show version.") do
          show_version
          exit
        end
      end

      parser.order(args) {|a| input[:assets] << a}
      input[:target] = input[:assets].shift
      input[:assets] = input[:assets].to_set

      input
    end

    def load_global_options
      return {} if ENV['HOME'].nil?
      file = Pathname.new(ENV['HOME']).join(SPROCKETS_FILE)

      load_options(file)
    end

    def load_local_options(root)
      file = root.join(SPROCKETS_FILE)

      load_options(file)
    end

    def load_options(file)
      return {} unless file.exist?

      raw = YAML.load(File.open(file))

      options = {}
      raw.each_pair do |key, value|
        options[key.to_sym] = value
      end

      options[:assets] = options[:assets].to_set
      options[:paths] = options[:paths].to_set if options[:paths].respond_to?(:to_set)

      options
    end

    def realpath(path)
      path = Pathname.new(path)
      return path.realpath if path.absolute?

      Pathname.new(@root).join(path)
    end

    def save_local_options
      File.open(@root.join(SPROCKETS_FILE), 'wb') do |f|
        YAML.dump({
          'target' => @local_options[:target],
          'paths' => (@local_options[:paths] || Set.new).to_a.map {|p| p.to_s},
          'assets' => @local_options[:assets].to_a.map {|a| a.to_s},
          'manifest' => @local_options[:manifest] || false,
          'manifest_path' => @local_options[:manifest_path],
          'digest' => @local_options[:digest] || false,
          'gzip' => @local_options[:gzip] || false
        }, f)
      end
    end
  end
end