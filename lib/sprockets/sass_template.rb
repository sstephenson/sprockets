require 'monitor'
require 'rack/utils'
require 'sass'

module Sprockets
  # Template engine class for the SASS/SCSS compiler. Depends on the `sass` gem.
  #
  # For more infomation see:
  #
  #   https://github.com/nex3/sass
  #   https://github.com/rails/sass-rails
  #
  class SassTemplate
    LOCK = Monitor.new

    # Internal: Defines default sass syntax to use. Exposed so the ScssTemplate
    # may override it.
    def self.syntax
      :sass
    end

    def self.call(*args)
      new.call(*args)
    end

    # Public: Initialize template with custom options.
    #
    # options - Hash
    #   cache_version - String custom cache version. Used to force a cache
    #                   change after code changes are made to Sass Functions.
    #
    def initialize(options = {}, &block)
      @cache_version = options[:cache_version]

      @functions = Module.new do
        include Functions
        include options[:functions] if options[:functions]
        class_eval(&block) if block_given?
      end
    end

    def call(input)
      context = input[:environment].context_class.new(input)

      options = {
        filename: input[:filename],
        syntax: self.class.syntax,
        cache_store: CacheStore.new(input[:cache], @cache_version),
        load_paths: input[:environment].paths,
        sprockets: {
          context: context,
          environment: input[:environment],
          dependencies: context.metadata[:dependency_paths]
        }
      }

      LOCK.synchronize do
        engine = ::Sass::Engine.new(input[:data], options)

        css = Utils.module_include(::Sass::Script::Functions, @functions) do
          engine.render
        end

        # Track all imported files
        engine.dependencies.map do |dependency|
          context.metadata[:dependency_paths] << dependency.options[:filename]
        end

        context.metadata.merge(data: css)
      end
    end

    # Public: Functions injected into Sass context during Sprockets evaluation.
    #
    # This module may be extended to add global functionality to all Sprockets
    # Sass environments. Though, scoping your functions to just your environment
    # is preferred.
    #
    # module Sprockets::SassTemplate::Functions
    #   def asset_path(path, options = {})
    #   end
    # end
    #
    module Functions
      # Public: Generate a url for asset path.
      #
      # Default implementation is deprecated. Currently defaults to
      # Context#asset_path.
      #
      # Will raise NotImplementedError in the future. Users should provide their
      # own base implementation.
      #
      # Returns a Sass::Script::String.
      def asset_path(path, options = {})
        ::Sass::Script::String.new(sprockets_context.asset_path(path.value, options), :string)
      end

      # Public: Generate a asset url() link.
      #
      # path - Sass::Script::String URL path
      #
      # Returns a Sass::Script::String.
      def asset_url(path, options = {})
        ::Sass::Script::String.new("url(#{asset_path(path, options).value})")
      end

      # Public: Generate url for image path.
      #
      # path - Sass::Script::String URL path
      #
      # Returns a Sass::Script::String.
      def image_path(path)
        asset_path(path, type: :image)
      end

      # Public: Generate a image url() link.
      #
      # path - Sass::Script::String URL path
      #
      # Returns a Sass::Script::String.
      def image_url(path)
        asset_url(path, type: :image)
      end

      # Public: Generate url for video path.
      #
      # path - Sass::Script::String URL path
      #
      # Returns a Sass::Script::String.
      def video_path(path)
        asset_path(path, type: :video)
      end

      # Public: Generate a video url() link.
      #
      # path - Sass::Script::String URL path
      #
      # Returns a Sass::Script::String.
      def video_url(path)
        asset_url(path, type: :video)
      end

      # Public: Generate url for audio path.
      #
      # path - Sass::Script::String URL path
      #
      # Returns a Sass::Script::String.
      def audio_path(path)
        asset_path(path, type: :audio)
      end

      # Public: Generate a audio url() link.
      #
      # path - Sass::Script::String URL path
      #
      # Returns a Sass::Script::String.
      def audio_url(path)
        asset_url(path, type: :audio)
      end

      # Public: Generate url for font path.
      #
      # path - Sass::Script::String URL path
      #
      # Returns a Sass::Script::String.
      def font_path(path)
        asset_path(path, type: :font)
      end

      # Public: Generate a font url() link.
      #
      # path - Sass::Script::String URL path
      #
      # Returns a Sass::Script::String.
      def font_url(path)
        asset_url(path, type: :font)
      end

      # Public: Generate url for javascript path.
      #
      # path - Sass::Script::String URL path
      #
      # Returns a Sass::Script::String.
      def javascript_path(path)
        asset_path(path, type: :javascript)
      end

      # Public: Generate a javascript url() link.
      #
      # path - Sass::Script::String URL path
      #
      # Returns a Sass::Script::String.
      def javascript_url(path)
        asset_url(path, type: :javascript)
      end

      # Public: Generate url for stylesheet path.
      #
      # path - Sass::Script::String URL path
      #
      # Returns a Sass::Script::String.
      def stylesheet_path(path)
        asset_path(path, type: :stylesheet)
      end

      # Public: Generate a stylesheet url() link.
      #
      # path - Sass::Script::String URL path
      #
      # Returns a Sass::Script::String.
      def stylesheet_url(path)
        asset_url(path, type: :stylesheet)
      end

      # Public: Generate a data URI for asset path.
      #
      # path - Sass::Script::String logical asset path
      #
      # Returns a Sass::Script::String.
      def asset_data_url(path)
        if asset = sprockets_environment.find_asset(path.value, accept_encoding: 'base64')
          sprockets_dependencies << asset.filename
          url = "data:#{asset.content_type};base64,#{Rack::Utils.escape(asset.to_s)}"
          ::Sass::Script::String.new("url(" + url + ")")
        end
      end

      protected
        # Public: The Environment.
        #
        # Returns Sprockets::Environment.
        def sprockets_environment
          options[:sprockets][:environment]
        end

        # Public: Mutatable set dependency paths.
        #
        # Returns a Set.
        def sprockets_dependencies
          options[:sprockets][:dependencies]
        end

        # Deprecated: Get the Context instance. Use APIs on
        # sprockets_environment or sprockets_dependencies directly.
        #
        # Returns a Context instance.
        def sprockets_context
          options[:sprockets][:context]
        end

    end

    # Internal: Cache wrapper for Sprockets cache adapter.
    class CacheStore < ::Sass::CacheStores::Base
      VERSION = '1'

      def initialize(cache, version)
        @cache, @version = cache, "#{VERSION}/#{version}"
      end

      def _store(key, version, sha, contents)
        @cache._set("#{@version}/#{version}/#{key}/#{sha}", contents)
      end

      def _retrieve(key, version, sha)
        @cache._get("#{@version}/#{version}/#{key}/#{sha}")
      end

      def path_to(key)
        key
      end
    end
  end

  class ScssTemplate < SassTemplate
    def self.syntax
      :scss
    end
  end

  # Deprecated: Use Sprockets::SassTemplate::Functions instead.
  SassFunctions = SassTemplate::Functions

  # Deprecated: Use Sprockets::SassTemplate::CacheStore instead.
  SassCacheStore = SassTemplate::CacheStore
end
