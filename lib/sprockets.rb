require 'sprockets/version'

module Sprockets
  autoload :ArgumentError,           "sprockets/errors"
  autoload :Asset,                   "sprockets/asset"
  autoload :AssetAttributes,         "sprockets/asset_attributes"
  autoload :BundledAsset,            "sprockets/bundled_asset"
  autoload :CharsetNormalizer,       "sprockets/charset_normalizer"
  autoload :CircularDependencyError, "sprockets/errors"
  autoload :ContentTypeMismatch,     "sprockets/errors"
  autoload :Context,                 "sprockets/context"
  autoload :DirectiveProcessor,      "sprockets/directive_processor"
  autoload :EcoTemplate,             "sprockets/eco_template"
  autoload :EjsTemplate,             "sprockets/ejs_template"
  autoload :EngineError,             "sprockets/errors"
  autoload :Engines,                 "sprockets/engines"
  autoload :Environment,             "sprockets/environment"
  autoload :Error,                   "sprockets/errors"
  autoload :FileNotFound,            "sprockets/errors"
  autoload :Index,                   "sprockets/index"
  autoload :JstProcessor,            "sprockets/jst_processor"
  autoload :Processing,              "sprockets/processing"
  autoload :Processor,               "sprockets/processor"
  autoload :SassImporter,            "sprockets/sass_template"
  autoload :SassResolver,            "sprockets/sass_template"
  autoload :SassTemplate,            "sprockets/sass_template"
  autoload :ScssTemplate,            "sprockets/sass_template"
  autoload :Server,                  "sprockets/server"
  autoload :StaticAsset,             "sprockets/static_asset"
  autoload :Utils,                   "sprockets/utils"

  module Cache
    autoload :FileStore, "sprockets/cache/file_store"
  end
end
