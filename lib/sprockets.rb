# autoload the various classes used in Sprockets
module Sprockets
  autoload :ArgumentError,       "sprockets/errors"
  autoload :ConcatenatedAsset,   "sprockets/concatenated_asset"
  autoload :ContentTypeMismatch, "sprockets/errors"
  autoload :Context,             "sprockets/context"
  autoload :DirectiveParser,     "sprockets/directive_parser"
  autoload :Environment,         "sprockets/environment"
  autoload :EnvironmentIndex,    "sprockets/environment_index"
  autoload :Error,               "sprockets/errors"
  autoload :FileNotFound,        "sprockets/errors"
  autoload :PathIndex,           "sprockets/path_index"
  autoload :Pathname,            "sprockets/pathname"
  autoload :Processor,           "sprockets/processor"
  autoload :SourceFile,          "sprockets/source_file"
  autoload :StaticAsset,         "sprockets/static_asset"
  autoload :StaticIndex,         "sprockets/static_index"
end
