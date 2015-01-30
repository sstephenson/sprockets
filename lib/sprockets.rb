require 'sprockets/version'

module Sprockets
  # Environment
  autoload :Asset,                   'sprockets/asset'
  autoload :Base,                    'sprockets/base'
  autoload :CachedEnvironment,       'sprockets/cached_environment'
  autoload :Environment,             'sprockets/environment'
  autoload :Manifest,                'sprockets/manifest'

  # Processing
  autoload :Bundle,                  'sprockets/bundle'
  autoload :CoffeeScriptTemplate,    'sprockets/coffee_script_template'
  autoload :Context,                 'sprockets/context'
  autoload :DirectiveProcessor,      'sprockets/directive_processor'
  autoload :FileReader,              'sprockets/file_reader'

  # Internal utilities
  autoload :ArgumentError,           'sprockets/errors'
  autoload :Cache,                   'sprockets/cache'
  autoload :ContentTypeMismatch,     'sprockets/errors'
  autoload :DigestUtils,             'sprockets/digest_utils'
  autoload :EncodingUtils,           'sprockets/encoding_utils'
  autoload :Error,                   'sprockets/errors'
  autoload :FileNotFound,            'sprockets/errors'
  autoload :HTTPUtils,               'sprockets/http_utils'
  autoload :PathUtils,               'sprockets/path_utils'
  autoload :Utils,                   'sprockets/utils'

  require 'sprockets/processor_utils'
  extend ProcessorUtils

  # Extend Sprockets module to provide global registry
  require 'sprockets/configuration'
  require 'sprockets/context'
  require 'digest/sha2'
  extend Configuration

  self.config = {
    bundle_processors: Hash.new { |h, k| [].freeze }.freeze,
    bundle_reducers: Hash.new { |h, k| {}.freeze }.freeze,
    dependencies: Set.new.freeze,
    dependency_resolvers: {}.freeze,
    compressors: Hash.new { |h, k| {}.freeze }.freeze,
    digest_class: Digest::SHA256,
    engine_mime_types: {}.freeze,
    engines: {}.freeze,
    inverted_transformers: Hash.new { |h, k| {}.freeze }.freeze,
    mime_exts: {}.freeze,
    mime_types: {}.freeze,
    paths: [].freeze,
    postprocessors: Hash.new { |h, k| [].freeze }.freeze,
    preprocessors: Hash.new { |h, k| [].freeze }.freeze,
    root: File.expand_path('..', __FILE__).freeze,
    transformers: Hash.new { |h, k| {}.freeze }.freeze,
    version: ""
  }.freeze

  @context_class = Context

  require 'logger'
  @logger = Logger.new($stderr)
  @logger.level = Logger::FATAL

  # Common asset text types
  register_mime_type 'application/javascript', extensions: ['.js'], charset: :unicode
  register_mime_type 'application/json', extensions: ['.json'], charset: :unicode
  register_mime_type 'application/xml', extensions: ['.xml']
  register_mime_type 'text/css', extensions: ['.css'], charset: :css
  register_mime_type 'text/html', extensions: ['.html', '.htm'], charset: :html
  register_mime_type 'text/plain', extensions: ['.txt', '.text']
  register_mime_type 'text/yaml', extensions: ['.yml', '.yaml'], charset: :unicode

  # Ruby extensions
  # register_mime_type 'application/css+ruby', extensions: ['.css.erb'], charset: :css
  # register_mime_type 'application/html+ruby', extensions: ['.html.erb', '.erb', '.rhtml'], charset: :html
  # register_mime_type 'application/javascript+ruby', extensions: ['.js.erb'], charset: :unicode
  register_mime_type 'application/json+ruby', extensions: ['.json.erb'], charset: :unicode
  # register_mime_type 'application/plain+ruby', extensions: ['.txt.erb', '.text.erb']
  register_mime_type 'application/ruby', extensions: ['.rb']
  register_mime_type 'application/xml+ruby', extensions: ['.xml.erb', '.rxml']
  # register_mime_type 'application/yaml+ruby', extensions: ['.yml.erb', '.yaml.erb'], charset: :unicode

  # Common image types
  register_mime_type 'image/x-icon', extensions: ['.ico']
  register_mime_type 'image/bmp', extensions: ['.bmp']
  register_mime_type 'image/gif', extensions: ['.gif']
  register_mime_type 'image/webp', extensions: ['.webp']
  register_mime_type 'image/png', extensions: ['.png']
  register_mime_type 'image/jpeg', extensions: ['.jpg', '.jpeg']
  register_mime_type 'image/tiff', extensions: ['.tiff', '.tif']
  register_mime_type 'image/svg+xml', extensions: ['.svg']

  # Common audio/video types
  register_mime_type 'video/webm', extensions: ['.webm']
  register_mime_type 'audio/basic', extensions: ['.snd', '.au']
  register_mime_type 'audio/aiff', extensions: ['.aiff']
  register_mime_type 'audio/mpeg', extensions: ['.mp3', '.mp2', '.m2a', '.m3a']
  register_mime_type 'application/ogg', extensions: ['.ogx']
  register_mime_type 'audio/midi', extensions: ['.midi', '.mid']
  register_mime_type 'video/avi', extensions: ['.avi']
  register_mime_type 'audio/wave', extensions: ['.wav', '.wave']
  register_mime_type 'video/mp4', extensions: ['.mp4', '.m4v']

  # Common font types
  register_mime_type 'application/vnd.ms-fontobject', extensions: ['.eot']
  register_mime_type 'application/x-font-ttf', extensions: ['.ttf']
  register_mime_type 'application/font-woff', extensions: ['.woff']

  require 'sprockets/directive_processor'
  register_preprocessor 'text/css', DirectiveProcessor.new(comments: ["//", ["/*", "*/"]])
  register_preprocessor 'application/javascript', DirectiveProcessor.new(comments: ["//", ["/*", "*/"]])

  require 'sprockets/bundle'
  register_bundle_processor 'application/javascript', Bundle
  register_bundle_processor 'text/css', Bundle

  register_bundle_metadata_reducer '*/*', :data, :+
  register_bundle_metadata_reducer 'application/javascript', :data, Utils.method(:concat_javascript_sources)
  register_bundle_metadata_reducer '*/*', :links, :+

  register_postprocessor 'application/javascript', proc { |input|
    # Use an identity map if no mapping is defined
    if !input[:metadata][:map]
      map = SourceMap::Map.new([
        SourceMap::Mapping.new(
          input[:name],
          SourceMap::Offset.new(0, 0),
          SourceMap::Offset.new(0, 0)
        )
      ])
      { data: input[:data], map: map }
    end
  }
  register_bundle_metadata_reducer 'application/javascript', :map, :+

  register_compressor 'text/css', :sass, autoload_processor(:SassCompressor, 'sprockets/sass_compressor')
  register_compressor 'text/css', :scss, autoload_processor(:SassCompressor, 'sprockets/sass_compressor')
  register_compressor 'text/css', :yui, autoload_processor(:YUICompressor, 'sprockets/yui_compressor')
  register_compressor 'application/javascript', :closure, autoload_processor(:ClosureCompressor, 'sprockets/closure_compressor')
  register_compressor 'application/javascript', :uglifier, autoload_processor(:UglifierCompressor, 'sprockets/uglifier_compressor')
  register_compressor 'application/javascript', :uglify, autoload_processor(:UglifierCompressor, 'sprockets/uglifier_compressor')
  register_compressor 'application/javascript', :yui, autoload_processor(:YUICompressor, 'sprockets/yui_compressor')

  # 6to5, TheFuture™ is now
  register_mime_type 'text/ecmascript-6', extensions: ['.es6'], charset: :unicode
  register_transformer 'text/ecmascript-6', 'application/javascript', autoload_processor(:ES6to5Processor, 'sprockets/es6to5_processor')
  register_preprocessor 'text/ecmascript-6', DirectiveProcessor.new(comments: ["//", ["/*", "*/"]])

  # Mmm, CoffeeScript
  register_mime_type 'text/coffeescript', extensions: ['.coffee', '.js.coffee']
  # register_mime_type 'application/coffeescript+ruby', extensions: ['.coffee.erb', '.js.coffee.erb']
  register_transformer 'text/coffeescript', 'application/javascript', autoload_processor(:CoffeeScriptProcessor, 'sprockets/coffee_script_processor')
  register_preprocessor 'text/coffeescript', DirectiveProcessor.new(comments: ["#", ["###", "###"]])

  # JST engines
  register_engine '.jst', autoload_processor(:JstProcessor, 'sprockets/jst_processor'), mime_type: 'application/javascript'
  register_engine '.eco', autoload_processor(:EcoProcessor, 'sprockets/eco_processor'), mime_type: 'application/javascript'
  register_engine '.ejs', autoload_processor(:EjsProcessor, 'sprockets/ejs_processor'), mime_type: 'application/javascript'

  # CSS engines
  register_mime_type 'text/sass', extensions: ['.sass', '.css.sass']
  register_mime_type 'text/scss', extensions: ['.scss', '.css.scss']
  # register_mime_type 'text/sass+ruby', extensions: ['.sass.erb', '.css.sass.erb']
  # register_mime_type 'text/scss+ruby', extensions: ['.scss.erb', '.css.scss.erb']
  register_transformer 'text/sass', 'text/css', autoload_processor(:SassProcessor, 'sprockets/sass_processor')
  register_transformer 'text/scss', 'text/css', autoload_processor(:ScssProcessor, 'sprockets/sass_processor')
  register_preprocessor 'text/sass', DirectiveProcessor.new(comments: ["//", ["/*", "*/"]])
  register_preprocessor 'text/scss', DirectiveProcessor.new(comments: ["//", ["/*", "*/"]])

  # Other
  register_engine '.erb', autoload_processor(:ERBProcessor, 'sprockets/erb_processor'), mime_type: 'text/plain'

  register_dependency_resolver 'environment-version' do |env|
    env.version
  end
  register_dependency_resolver 'environment-paths' do |env|
    env.paths
  end
  register_dependency_resolver 'file-digest' do |env, str|
    env.file_digest(env.parse_file_digest_uri(str))
  end
  register_dependency_resolver 'processors' do |env, str|
    env.resolve_processors_cache_key_uri(str)
  end

  depend_on 'environment-version'
  depend_on 'environment-paths'
end
