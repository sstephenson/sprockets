require 'sprockets/asset_with_dependencies'

module Sprockets
  class ProcessedAsset < AssetWithDependencies
    def initialize(environment, logical_path, pathname)
      super

      start_time = Time.now.to_f

      context = environment.context_class.new(environment, logical_path, pathname)
      @source = context.evaluate(pathname)
      @length = Rack::Utils.bytesize(source)
      @digest = environment.digest.update(source).hexdigest

      build_required_assets(environment, context)
      build_dependency_paths(environment, context)

      @dependency_digest = compute_dependency_digest(environment)

      elapsed_time = ((Time.now.to_f - start_time) * 1000).to_i
      environment.logger.debug "Compiled #{logical_path}  (#{elapsed_time}ms)  (pid #{Process.pid})"
    end
  end
end
