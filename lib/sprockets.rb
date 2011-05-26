module Sprockets
  VERSION = "2.0.0.beta.8"

  autoload :ArgumentError,           "sprockets/errors"
  autoload :AssetAttributes,         "sprockets/asset_attributes"
  autoload :BundledAsset,            "sprockets/bundled_asset"
  autoload :CharsetNormalizer,       "sprockets/charset_normalizer"
  autoload :CircularDependencyError, "sprockets/errors"
  autoload :Compressor,              "sprockets/compressor"
  autoload :ContentTypeMismatch,     "sprockets/errors"
  autoload :Context,                 "sprockets/context"
  autoload :DirectiveProcessor,      "sprockets/directive_processor"
  autoload :EjsTemplate,             "sprockets/ejs_template"
  autoload :Engines,                 "sprockets/engines"
  autoload :Environment,             "sprockets/environment"
  autoload :EnvironmentIndex,        "sprockets/environment_index"
  autoload :Error,                   "sprockets/errors"
  autoload :FileNotFound,            "sprockets/errors"
  autoload :JstProcessor,            "sprockets/jst_processor"
  autoload :Processing,              "sprockets/processing"
  autoload :Server,                  "sprockets/server"
  autoload :StaticAsset,             "sprockets/static_asset"
  autoload :StaticCompilation,       "sprockets/static_compilation"
  autoload :Utils,                   "sprockets/utils"
end

# TODO: Remove in 2.0.0 final
if defined?(Rails::VERSION::STRING) && Rails::VERSION::STRING.match(/^3\.1\.0\.beta/)
  message = "WARNING: Sprockets #{Sprockets::VERSION} is incompatible with Rails #{Rails::VERSION::STRING}. Please upgrade to Rails 3.1.0.rc1 or higher."
  if defined?(Rails.logger) && Rails.logger
    Rails.logger.warn(message)
  else
    warn(message)
  end
end
