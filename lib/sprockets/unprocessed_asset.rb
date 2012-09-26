require 'sprockets/asset_with_dependencies'

module Sprockets
  class UnprocessedAsset < AssetWithDependencies
    def initialize(environment, logical_path, pathname)
      super

      context = environment.context_class.new(environment, logical_path, pathname)
      attributes = environment.attributes_for(pathname)
      processors = attributes.processors

      # Remove all engine processors except ERB to return unprocessed source file
      processors -= (attributes.engines - [Tilt::ERBTemplate])

      @source = context.evaluate(pathname, :processors => processors)

      build_required_assets(environment, context,  :process => false)
      build_dependency_paths(environment, context, :process => false)

      @dependency_digest = compute_dependency_digest(environment)
    end
  end

  # Return unprocessed dependencies when initializing asset from serialized hash
  def init_with(environment, coder)
    super(environment, coder, :process => false)
  end
end
