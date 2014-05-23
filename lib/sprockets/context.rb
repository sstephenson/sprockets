require 'base64'
require 'pathname'
require 'rack/utils'
require 'set'
require 'sprockets/errors'
require 'sprockets/utils'

module Sprockets
  # Deprecated: `Context` provides helper methods to all `Template` processors.
  # They are typically accessed by ERB templates. You can mix in custom helpers
  # by injecting them into `Environment#context_class`. Do not mix them into
  # `Context` directly.
  #
  #     environment.context_class.class_eval do
  #       include MyHelper
  #       def asset_url; end
  #     end
  #
  #     <%= asset_url "foo.png" %>
  #
  # The `Context` also collects dependencies declared by
  # assets. See `DirectiveProcessor` for an example of this.
  class Context
    attr_reader :environment, :pathname

    def initialize(input)
      @environment  = input[:environment]
      @metadata     = input[:metadata]
      @root_path    = input[:root_path]
      @logical_path = input[:logical_path]
      @filename     = input[:filename]
      @pathname     = Pathname.new(@filename)
      @content_type = input[:content_type]
      @root_path, _ = @environment.paths_split(@environment.paths, @filename)

      @required_paths   = Set.new(@metadata[:required_paths])
      @stubbed_paths    = Set.new(@metadata[:stubbed_paths])
      @dependency_paths = Set.new(@metadata[:dependency_paths])
    end

    def metadata
      { required_paths: @required_paths,
        stubbed_paths: @stubbed_paths,
        dependency_paths: @dependency_paths }
    end

    # Returns the environment path that contains the file.
    #
    # If `app/javascripts` and `app/stylesheets` are in your path, and
    # current file is `app/javascripts/foo/bar.js`, `root_path` would
    # return `app/javascripts`.
    attr_reader :root_path

    # Returns logical path without any file extensions.
    #
    #     'app/javascripts/application.js'
    #     # => 'application'
    #
    attr_reader :logical_path

    # Returns content type of file
    #
    #     'application/javascript'
    #     'text/css'
    #
    attr_reader :content_type

    # Given a logical path, `resolve` will find and return the fully
    # expanded path. Relative paths will also be resolved. An optional
    # `:content_type` restriction can be supplied to restrict the
    # search.
    #
    #     resolve("foo.js")
    #     # => "/path/to/app/javascripts/foo.js"
    #
    #     resolve("./bar.js")
    #     # => "/path/to/app/javascripts/bar.js"
    #
    def resolve(path, options = {})
      options[:content_type] = self.content_type if options[:content_type] == :self
      path = environment.normalize_path(path, @filename)
      environment.resolve(path, options)
    end

    # `depend_on` allows you to state a dependency on a file without
    # including it.
    #
    # This is used for caching purposes. Any changes made to
    # the dependency file with invalidate the cache of the
    # source file.
    def depend_on(path)
      @dependency_paths << resolve(path).to_s
      nil
    end

    # `depend_on_asset` allows you to state an asset dependency
    # without including it.
    #
    # This is used for caching purposes. Any changes that would
    # invalidate the dependency asset will invalidate the source
    # file. Unlike `depend_on`, this will include recursively include
    # the target asset's dependencies.
    def depend_on_asset(path)
      if asset = @environment.find_asset(resolve(path))
        @dependency_paths.merge(asset.metadata[:dependency_paths])
      end
      nil
    end

    # `require_asset` declares `path` as a dependency of the file. The
    # dependency will be inserted before the file and will only be
    # included once.
    #
    # If ERB processing is enabled, you can use it to dynamically
    # require assets.
    #
    #     <%= require_asset "#{framework}.js" %>
    #
    def require_asset(path)
      pathname = resolve(path, content_type: :self)
      depend_on_asset(pathname)
      @required_paths << pathname.to_s
      nil
    end

    # `stub_asset` blacklists `path` from being included in the bundle.
    # `path` must be an asset which may or may not already be included
    # in the bundle.
    def stub_asset(path)
      @stubbed_paths << resolve(path, content_type: :self).to_s
      nil
    end

    # Returns a Base64-encoded `data:` URI with the contents of the
    # asset at the specified path, and marks that path as a dependency
    # of the current file.
    #
    # Use `asset_data_uri` from ERB with CSS or JavaScript assets:
    #
    #     #logo { background: url(<%= asset_data_uri 'logo.png' %>) }
    #
    #     $('<img>').attr('src', '<%= asset_data_uri 'avatar.jpg' %>')
    #
    def asset_data_uri(path)
      depend_on_asset(path)
      asset  = environment.find_asset(path)
      base64 = Base64.strict_encode64(asset.to_s)
      "data:#{asset.content_type};base64,#{Rack::Utils.escape(base64)}"
    end

    # Expands logical path to full url to asset.
    #
    # NOTE: This helper is currently not implemented and should be
    # customized by the application. Though, in the future, some
    # basics implemention may be provided with different methods that
    # are required to be overridden.
    def asset_path(path, options = {})
      message = <<-EOS
Custom asset_path helper is not implemented

Extend your environment context with a custom method.

    environment.context_class.class_eval do
      def asset_path(path, options = {})
      end
    end
      EOS
      raise NotImplementedError, message
    end

    # Expand logical image asset path.
    def image_path(path)
      asset_path(path, type: :image)
    end

    # Expand logical video asset path.
    def video_path(path)
      asset_path(path, type: :video)
    end

    # Expand logical audio asset path.
    def audio_path(path)
      asset_path(path, type: :audio)
    end

    # Expand logical font asset path.
    def font_path(path)
      asset_path(path, type: :font)
    end

    # Expand logical javascript asset path.
    def javascript_path(path)
      asset_path(path, type: :javascript)
    end

    # Expand logical stylesheet asset path.
    def stylesheet_path(path)
      asset_path(path, type: :stylesheet)
    end
  end
end
