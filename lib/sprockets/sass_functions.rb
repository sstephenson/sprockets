require 'sass'

module Sprockets
  module SassFunctions
    def self.define_functions(obj)
      obj.class_eval do
        def asset_path(path)
          Sass::Script::String.new(sprockets_context.asset_path(path.value), :string)
        end

        def asset_url(path)
          Sass::Script::String.new("url(" + sprockets_context.asset_path(path.value) + ")")
        end

        def image_path(path)
          Sass::Script::String.new(sprockets_context.image_path(path.value), :string)
        end

        def image_url(path)
          Sass::Script::String.new("url(" + sprockets_context.image_path(path.value) + ")")
        end

        def video_path(path)
          Sass::Script::String.new(sprockets_context.video_path(path.value), :string)
        end

        def video_url(path)
          Sass::Script::String.new("url(" + sprockets_context.video_path(path.value) + ")")
        end

        def audio_path(path)
          Sass::Script::String.new(sprockets_context.audio_path(path.value), :string)
        end

        def audio_url(path)
          Sass::Script::String.new("url(" + sprockets_context.audio_path(path.value) + ")")
        end

        def font_path(path)
          Sass::Script::String.new(sprockets_context.font_path(path.value), :string)
        end

        def font_url(path)
          Sass::Script::String.new("url(" + sprockets_context.font_path(path.value) + ")")
        end

        def javascript_path(path)
          Sass::Script::String.new(sprockets_context.javascript_path(path.value), :string)
        end

        def javascript_url(path)
          Sass::Script::String.new("url(" + sprockets_context.javascript_path(path.value) + ")")
        end

        def stylesheet_path(path)
          Sass::Script::String.new(sprockets_context.stylesheet_path(path.value), :string)
        end

        def stylesheet_url(path)
          Sass::Script::String.new("url(" + sprockets_context.stylesheet_path(path.value) + ")")
        end

        protected
          def sprockets_context
            options[:sprockets][:context]
          end

          def sprockets_environment
            options[:sprockets][:environment]
          end
      end

      if block_given?
        begin
          yield
        ensure
          obj.class_eval do
            remove_method :asset_path, :asset_url,
              :image_path, :image_url,
              :video_path, :video_url,
              :audio_path, :audio_url,
              :font_path, :font_url,
              :javascript_path, :javascript_url,
              :stylesheet_path, :stylesheet_url,
              :sprockets_context, :sprockets_environment
          end
        end
      end
    end
  end
end
