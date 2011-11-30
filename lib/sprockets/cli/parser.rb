require 'optparse'
require 'ostruct'
require 'pathname'
require 'set'
require 'fileutils'

module Sprockets
  module CLI
    class Parser
      attr_reader :parser, :options, :target, :paths

      def compile
        env = Sprockets::Environment.new(options.delete(:root))
        paths.each {|p| env.append_path(p)}

        assets = options.delete(:assets).map {|a| realpath(a).to_s}
        filter = Proc.new do |asset|
          assets.any? {|a| asset.pathname.to_s.start_with?(a)}
        end

        compiler = Sprockets::Compiler.new(env, target, [filter], options)
        compiler.compile
      end

      def initialize
        initialize_options
        initialize_parser
      end

      def parse(*args)
        parser.order(args) {|a| options[:assets] << a}
        @target = options[:assets].shift

        if args.length == 0 || target.to_s.length == 0 || options[:assets].length == 0
          show_usage
        else
          @paths = Set.new
          options[:assets].each {|a| @paths << (File.file?(a) ? realpath(a).dirname : a)}
          options[:paths].each {|p| @paths << realpath(p)}
          @paths += ENV['SPROCKETS_PATH'].split(':') unless ENV['SPROCKETS_PATH'].nil?

          compile
        end
      rescue OptionParser::InvalidOption => e
        puts_error e.message
        show_usage
      rescue Sprockets::FileNotFound => e
        puts_error e.message
      end

      def puts_error(message)
        puts "\e[31msprocketize: #{message}\e[0m"
      end

      def show_usage
        puts parser
      end

      def show_version
        puts ::Sprockets::VERSION
      end

      private

      def exit_if_non_existent(path)
        return if File.exists?(path)
        puts "No such file or directory #{path}"
        exit
      end

      def initialize_options
        @options = {
            :root => '.',
            :paths => [],
            :assets => [],
            :digest => false,
            :manifest => false,
            :manifest_path => nil
        }
      end

      def initialize_parser
        @parser = OptionParser.new do |opts|
          opts.banner = "Usage: sprocketize [options] output_directory filename [filename ...]"

          opts.on("-a DIRECTORY", "--asset-root=DIRECTORY", "Assets root path.") do |dir|
            exit_if_non_existent(dir)
            options[:root] = realpath(dir)
          end

          opts.on("-I DIRECTORY", "--include-dir=DIRECTORY", "Adds the directory to the Sprockets load path.") do |dir|
            exit_if_non_existent(dir)
            options[:paths] << realpath(dir)
          end

          opts.on("-d", "--digest", "Incorporates a MD5 digest into all filenames.") do
            options[:digest] = true
          end

          opts.on("-m [DIRECTORY]", "--manifest [=DIRECTORY]", "Writes a manifest for the assets. If no directory is specified the manifest will be written to the output directory.") do |dir|
            options[:manifest] = true
            options[:manifest_path] = dir
          end

          opts.on("-c", "--compress", "Also create a compressed version of all Stylesheets and Javascripts.") do |dir|
            options[:compress] = true
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
      end

      def realpath(path)
        Pathname.new(path).realpath
      end
    end
  end
end