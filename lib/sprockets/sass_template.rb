require 'base64'
require 'rack/utils'
require 'sass'
require 'set'

module Sprockets
  # Template engine class for the SASS/SCSS compiler. Depends on the `sass` gem.
  #
  # For more infomation see:
  #
  #   https://github.com/nex3/sass
  #   https://github.com/rails/sass-rails
  #
  class SassTemplate
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
    def initialize(options = {})
      unless ::Sass::Script::Functions < SassFunctions
        # Install custom functions. It'd be great if this didn't need to
        # be installed globally, but could be passed into Engine as an
        # option.
        ::Sass::Script::Functions.send :include, SassFunctions
      end

      @cache_version = options[:cache_version]
    end

    def call(input)
      context = input[:environment].context_class.new(input)

      options = {
        filename: input[:filename],
        syntax: self.class.syntax,
        cache_store: SassCacheStore.new(input[:cache], @cache_version),
        load_paths: input[:environment].paths,
        sprockets: {
          context: context,
          environment: input[:environment],
          dependencies: context.metadata[:dependency_paths]
        }
      }

      engine = ::Sass::Engine.new(input[:data], options)
      css = engine.render

      # Track all imported files
      engine.dependencies.map do |dependency|
        context.metadata[:dependency_paths] << dependency.options[:filename]
      end

      context.metadata.merge(data: css)
    end
  end

  class ScssTemplate < SassTemplate
    def self.syntax
      :scss
    end
  end

  # Internal: Cache wrapper for Sprockets cache adapter.
  class SassCacheStore < ::Sass::CacheStores::Base
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

  # Internal: Functions injected into Sass environment.
  module SassFunctions
    def asset_path(path)
      Sass::Script::String.new(sprockets_asset_path(path.value), :string)
    end

    def asset_url(path)
      Sass::Script::String.new("url(" + sprockets_asset_path(path.value) + ")")
    end

    def image_path(path)
      Sass::Script::String.new(sprockets_asset_path(path.value, type: :image), :string)
    end

    def image_url(path)
      Sass::Script::String.new("url(" + sprockets_asset_path(path.value, type: :image) + ")")
    end

    def video_path(path)
      Sass::Script::String.new(sprockets_asset_path(path.value, type: :video), :string)
    end

    def video_url(path)
      Sass::Script::String.new("url(" + sprockets_asset_path(path.value, type: :video) + ")")
    end

    def audio_path(path)
      Sass::Script::String.new(sprockets_asset_path(path.value, type: :audio), :string)
    end

    def audio_url(path)
      Sass::Script::String.new("url(" + sprockets_asset_path(path.value, type: :audio) + ")")
    end

    def font_path(path)
      Sass::Script::String.new(sprockets_asset_path(path.value, type: :font), :string)
    end

    def font_url(path)
      Sass::Script::String.new("url(" + sprockets_asset_path(path.value, type: :font) + ")")
    end

    def javascript_path(path)
      Sass::Script::String.new(sprockets_asset_path(path.value, type: :javascript), :string)
    end

    def javascript_url(path)
      Sass::Script::String.new("url(" + sprockets_asset_path(path.value, type: :javascript) + ")")
    end

    def stylesheet_path(path)
      Sass::Script::String.new(sprockets_asset_path(path.value, type: :stylesheet), :string)
    end

    def stylesheet_url(path)
      Sass::Script::String.new("url(" + sprockets_asset_path(path.value, type: :stylesheet) + ")")
    end

    def asset_data_url(path)
      if asset = sprockets_environment.find_asset(path.value)
        sprockets_dependencies << asset.filename
        base64 = Base64.strict_encode64(asset.to_s)
        url = "data:#{asset.content_type};base64,#{Rack::Utils.escape(base64)}"
        Sass::Script::String.new("url(" + url + ")")
      end
    end

    protected
      def sprockets_asset_path(path, options = {})
        sprockets_context.asset_path(path, options)
      end

      def sprockets_context
        options[:sprockets][:context]
      end

      def sprockets_environment
        options[:sprockets][:environment]
      end

      def sprockets_dependencies
        options[:sprockets][:dependencies]
      end
  end
end
