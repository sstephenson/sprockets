require 'sprockets_test'
require 'rack/mock'
require 'execjs'

module EnvironmentTests
  def self.test(name, &block)
    define_method("test_#{name.inspect}", &block)
  end

  test "working directory is the default root" do
    assert_equal Dir.pwd, @env.root
  end

  test "default logger level is set to fatal" do
    assert_equal Logger::FATAL, @env.logger.level
  end

  test "active css compressor" do
    assert_nil @env.css_compressor
  end

  test "active js compressor" do
    assert_nil @env.js_compressor
  end

  test "paths" do
    assert_equal [fixture_path("default")], @env.paths.to_a
  end

  test "register global path" do
    assert_equal [fixture_path("default")], new_environment.paths.to_a
    Sprockets.append_path(fixture_path("asset"))
    assert_equal [fixture_path("asset"), fixture_path("default")], new_environment.paths.to_a
    Sprockets.clear_paths
  end

  test "extensions" do
    ["coffee", "erb", "less", "sass", "scss", "str", "css", "js"].each do |ext|
      assert @env.extensions.to_a.include?(".#{ext}"), "'.#{ext}' not in #{@env.extensions.inspect}"
    end
  end

  test "engine extensions" do
    ["coffee", "erb", "less", "sass", "scss", "str"].each do |ext|
      assert @env.engine_extensions.include?(".#{ext}")
    end
    ["css", "js"].each do |ext|
      assert !@env.engine_extensions.include?(".#{ext}")
    end
  end

  test "format extensions" do
    ["css", "js"].each do |ext|
      assert @env.format_extensions.include?(".#{ext}")
    end
    ["coffee", "erb", "less", "sass", "scss", "str"].each do |ext|
      assert !@env.format_extensions.include?(".#{ext}")
    end
  end

  test "eco templates" do
    asset = @env["goodbye.jst"]
    context = ExecJS.compile(asset.to_s)
    assert_equal "Goodbye world\n", context.call("JST['goodbye']", :name => "world")
  end

  test "ejs templates" do
    asset = @env["hello.jst"]
    context = ExecJS.compile(asset.to_s)
    assert_equal "hello: world\n", context.call("JST['hello']", :name => "world")
  end

  test "asset_data_uri helper" do
    asset = @env["with_data_uri.css"]
    assert_equal "body {\n  background-image: url(data:image/gif;base64,R0lGODlhAQABAIAAAP%2F%2F%2FwAAACH5BAAAAAAALAAAAAABAAEAAAICRAEAOw%3D%3D) no-repeat;\n}\n", asset.to_s
  end

  test "lookup mime type" do
    assert_equal "application/javascript", @env.mime_types(".js")
    assert_equal "application/javascript", @env.mime_types("js")
    assert_equal "text/css", @env.mime_types(:css)
    assert_equal nil, @env.mime_types("foo")
    assert_equal nil, @env.mime_types("foo")
  end

  test "lookup bundle processors" do
    assert_equal [], @env.bundle_processors('application/javascript')
    assert_equal [Sprockets::CharsetNormalizer], @env.bundle_processors('text/css')
  end

  test "lookup compressors" do
    assert_equal Sprockets::SassCompressor, @env.compressors['text/css'][:sass]
    assert_equal Sprockets::UglifierCompressor, @env.compressors['application/javascript'][:uglifier]
  end

  test "resolve in environment" do
    assert_equal fixture_path('default/gallery.js'),
      @env.resolve("gallery.js").to_s
    assert_equal fixture_path('default/gallery.js'),
      @env.resolve(Pathname.new("gallery.js")).to_s
    assert_equal fixture_path('default/coffee/foo.coffee'),
      @env.resolve("coffee/foo.js").to_s
  end

  test "missing file raises an exception" do
    assert_raises(Sprockets::FileNotFound) do
      @env.resolve("null")
    end
  end

  test "find bundled asset in environment" do
    assert_equal "var Gallery = {};\n", @env["gallery.js"].to_s
  end

  test "find bundled asset with absolute path environment" do
    assert_equal "var Gallery = {};\n", @env[fixture_path("default/gallery.js")].to_s
  end

  test "find bundled asset with implicit format" do
    assert_equal "(function() {\n  var foo;\n\n  foo = 'hello';\n\n}).call(this);\n",
      @env["coffee/foo.js"].to_s
  end

  test "find static asset in environment" do
    assert_equal "Hello world\n", @env["hello.txt"].to_s
  end

  test "find static asset with leading slash in environment" do
    assert_equal "Hello world\n", @env[fixture_path("default/hello.txt")].to_s
  end

  test "find index.js in directory" do
    assert_equal "var A;\nvar B;\n", @env["mobile.js"].to_s
  end

  test "find index.css in directory" do
    assert_equal ".c {}\n.d {}\n/*\n\n */\n\n", @env["mobile.css"].to_s
  end

  test "find component.json in directory" do
    assert_equal "var bower;\n", @env["bower.js"].to_s
  end

  test "find multiple component.json in directory" do
    assert_equal "var qunit;\n", @env["qunit.js"].to_s
    assert_equal ".qunit {}\n", @env["qunit.css"].to_s
  end

  test "missing static path returns nil" do
    assert_nil @env[fixture_path("default/missing.png")]
  end

  test "find static directory returns nil" do
    assert_nil @env["images"]
  end

  test "missing asset returns nil" do
    assert_equal nil, @env["missing.js"]
  end

  test "missing asset path returns nil" do
    assert_nil @env[fixture_path("default/missing.js")]
  end

  test "asset with missing requires raises an exception" do
    assert_raises Sprockets::FileNotFound do
      @env["missing_require.js"]
    end
  end

  test "asset with missing depend_on raises an exception" do
    assert_raises Sprockets::FileNotFound do
      @env["missing_depend_on.js"]
    end
  end

  test "asset with missing absolute depend_on raises an exception" do
    assert_raises Sprockets::FileNotFound do
      @env["missing_absolute_depend_on.js"]
    end
  end

  test "asset logical path for absolute path" do
    assert_equal "gallery.js",
      @env[fixture_path("default/gallery.js")].logical_path
    assert_equal "application.js",
      @env[fixture_path("default/application.js.coffee")].logical_path
    assert_equal "mobile/a.js",
      @env[fixture_path("default/mobile/a.js")].logical_path
  end

  ENTRIES_IN_PATH = 43

  test "iterate over each entry" do
    entries = []
    @env.each_entry(fixture_path("default")) do |path|
      entries << path
    end
    assert_equal ENTRIES_IN_PATH, entries.length
  end

  test "each entry enumerator" do
    enum = @env.each_entry(fixture_path("default"))
    assert_equal ENTRIES_IN_PATH, enum.to_a.length
  end

  FILES_IN_PATH = 36

  test "iterate over each file" do
    files = []
    @env.each_file do |filename|
      files << filename
    end
    assert_equal FILES_IN_PATH, files.length
  end

  test "each file enumerator" do
    enum = @env.each_file
    assert_equal FILES_IN_PATH, enum.to_a.length
  end

  test "iterate over each logical path" do
    paths = []
    @env.each_logical_path do |logical_path|
      paths << logical_path
    end
    assert_equal FILES_IN_PATH, paths.length
    assert_equal paths.size, paths.uniq.size, "has duplicates"

    assert paths.include?("application.js")
    assert paths.include?("coffee/foo.js")
    assert paths.include?("coffee/index.js")
    assert !paths.include?("coffee")
  end

  test "iterate over each logical path and filename" do
    paths = []
    filenames = []
    @env.each_logical_path do |logical_path, filename|
      paths << logical_path
      filenames << filename
    end
    assert_equal FILES_IN_PATH, paths.length
    assert_equal paths.size, paths.uniq.size, "has duplicates"

    assert paths.include?("application.js")
    assert paths.include?("coffee/foo.js")
    assert paths.include?("coffee/index.js")
    assert !paths.include?("coffee")

    assert filenames.any? { |p| p =~ /application.js.coffee/ }
  end

  test "each logical path enumerator" do
    enum = @env.each_logical_path
    assert_kind_of String, enum.first
    assert_equal FILES_IN_PATH, enum.to_a.length
  end

  test "iterate over each logical path matching fnmatch filters" do
    paths = []
    @env.each_logical_path("*.js") do |logical_path|
      paths << logical_path
    end

    assert paths.include?("application.js")
    assert paths.include?("coffee/foo.js")
    assert !paths.include?("gallery.css")
  end

  test "iterate over each logical path matches index files" do
    paths = []
    @env.each_logical_path("coffee.js") do |logical_path|
      paths << logical_path
    end
    assert paths.include?("coffee.js")
    assert !paths.include?("coffee/index.js")
  end

  test "each logical path enumerator matching fnmatch filters" do
    paths = []
    enum = @env.each_logical_path("*.js")
    enum.to_a.each do |logical_path|
      paths << logical_path
    end

    assert paths.include?("application.js")
    assert paths.include?("coffee/foo.js")
    assert !paths.include?("gallery.css")
  end

  test "iterate over each logical path matching regexp filters" do
    paths = []
    @env.each_logical_path(/.*\.js/) do |logical_path|
      paths << logical_path
    end

    assert paths.include?("application.js")
    assert paths.include?("coffee/foo.js")
    assert !paths.include?("gallery.css")
  end

  test "iterate over each logical path matching proc filters" do
    paths = []
    @env.each_logical_path(proc { |fn| File.extname(fn) == '.js' }) do |logical_path|
      paths << logical_path
    end

    assert paths.include?("application.js")
    assert paths.include?("coffee/foo.js")
    assert !paths.include?("gallery.css")
  end

  test "iterate over each logical path matching proc filters with full path arg" do
    paths = []
    @env.each_logical_path(proc { |_, fn| fn.match(fixture_path('default/mobile')) }) do |logical_path|
      paths << logical_path
    end

    assert paths.include?("mobile/a.js")
    assert paths.include?("mobile/b.js")
    assert !paths.include?("application.js")
  end

  test "CoffeeScript files are compiled in a closure" do
    script = @env["coffee"].to_s
    assert_equal "undefined", ExecJS.exec(script)
  end
end

class WhitespaceCompressor
  def self.compress(source)
    source.gsub(/\s+/, "")
  end
end

class TestEnvironment < Sprockets::TestCase
  include EnvironmentTests

  def new_environment
    Sprockets::Environment.new(".") do |env|
      env.append_path(fixture_path('default'))
      env.cache = {}
      yield env if block_given?
    end
  end

  def setup
    @env = new_environment
  end

  test "changing logger" do
    @env.logger = Logger.new($stderr)
  end

  test "changing paths" do
    @env.clear_paths
    @env.append_path(fixture_path('asset'))
  end

  test "register mime type" do
    assert !@env.mime_types("jst")
    @env.register_mime_type("application/javascript", "jst")
    assert_equal "application/javascript", @env.mime_types("jst")
  end

  test "register bundle processor" do
    assert !@env.bundle_processors('text/css').include?(WhitespaceCompressor)
    @env.register_bundle_processor 'text/css', WhitespaceCompressor
    assert @env.bundle_processors('text/css').include?(WhitespaceCompressor)
  end

  test "register compressor" do
    assert !@env.compressors['text/css'][:whitespace]
    @env.register_compressor 'text/css', :whitespace, WhitespaceCompressor
    assert @env.compressors['text/css'][:whitespace]
  end

  test "register global block preprocessor" do
    old_size = new_environment.preprocessors('text/css').size
    Sprockets.register_preprocessor('text/css', :foo) { |context, data| data }
    assert_equal old_size+1, new_environment.preprocessors('text/css').size
    Sprockets.unregister_preprocessor('text/css', :foo)
    assert_equal old_size, new_environment.preprocessors('text/css').size
  end

  test "unregister custom block preprocessor" do
    old_size = @env.preprocessors('text/css').size
    @env.register_preprocessor('text/css', :foo) { |context, data| data }
    assert_equal old_size+1, @env.preprocessors('text/css').size
    @env.unregister_preprocessor('text/css', :foo)
    assert_equal old_size, @env.preprocessors('text/css').size
  end

  test "unregister custom block postprocessor" do
    old_size = @env.postprocessors('text/css').size
    @env.register_postprocessor('text/css', :foo) { |context, data| data }
    assert_equal old_size+1, @env.postprocessors('text/css').size
    @env.unregister_postprocessor('text/css', :foo)
    assert_equal old_size, @env.postprocessors('text/css').size
  end

  test "register global block postprocessor" do
    old_size = new_environment.postprocessors('text/css').size
    Sprockets.register_postprocessor('text/css', :foo) { |context, data| data }
    assert_equal old_size+1, new_environment.postprocessors('text/css').size
    Sprockets.unregister_postprocessor('text/css', :foo)
    assert_equal old_size, new_environment.postprocessors('text/css').size
  end

  test "unregister custom block bundle processor" do
    old_size = @env.bundle_processors('text/css').size
    @env.register_bundle_processor('text/css', :foo) { |context, data| data }
    assert_equal old_size+1, @env.bundle_processors('text/css').size
    @env.unregister_bundle_processor('text/css', :foo)
    assert_equal old_size, @env.bundle_processors('text/css').size
  end

  test "register global bundle processor" do
    assert !@env.bundle_processors('text/css').include?(WhitespaceCompressor)
    Sprockets.register_bundle_processor 'text/css', WhitespaceCompressor
    env = new_environment
    assert env.bundle_processors('text/css').include?(WhitespaceCompressor)
    Sprockets.unregister_bundle_processor 'text/css', WhitespaceCompressor
  end

  test "setting css compressor to nil clears current compressor" do
    @env.css_compressor = WhitespaceCompressor
    assert @env.css_compressor
    @env.css_compressor = nil
    assert_nil @env.css_compressor
  end

  test "setting js compressor to nil clears current compressor" do
    @env.js_compressor = WhitespaceCompressor
    assert @env.js_compressor
    @env.js_compressor = nil
    assert_nil @env.js_compressor
  end

  test "setting js compressor to tilt handler" do
    assert_nil @env.js_compressor
    @env.js_compressor = Sprockets::UglifierCompressor
    assert_equal Sprockets::UglifierCompressor, @env.js_compressor
    @env.js_compressor = nil
    assert_nil @env.js_compressor
  end

  test "setting css compressor to tilt handler" do
    assert_nil @env.css_compressor
    @env.css_compressor = Sprockets::SassCompressor
    assert_equal Sprockets::SassCompressor, @env.css_compressor
    @env.css_compressor = nil
    assert_nil @env.css_compressor
  end

  test "setting js compressor to sym" do
    assert_nil @env.js_compressor
    @env.js_compressor = :uglifier
    assert_equal Sprockets::UglifierCompressor, @env.js_compressor
    @env.js_compressor = nil
    assert_nil @env.js_compressor
  end

  test "setting css compressor to sym" do
    assert_nil @env.css_compressor
    @env.css_compressor = :sass
    assert_equal Sprockets::SassCompressor, @env.css_compressor
    @env.css_compressor = nil
    assert_nil @env.css_compressor
  end

  test "changing digest implementation class" do
    old_digest = @env.digest
    old_asset_digest = @env["gallery.js"].digest

    require 'digest/sha1'
    @env.digest_class = Digest::SHA1

    assert old_digest != @env.digest
    assert old_asset_digest != @env["gallery.js"].digest
  end

  test "changing digest version" do
    old_digest = @env.digest
    old_asset_digest = @env["gallery.js"].digest

    @env.version = 'v2'

    assert old_digest != @env.digest
    assert old_asset_digest != @env["gallery.js"].digest
  end

  test "bundled asset is stale if its mtime is updated or deleted" do
    filename = File.join(fixture_path("default"), "tmp.js")

    sandbox filename do
      assert_nil @env["tmp.js"]

      File.open(filename, 'w') { |f| f.puts "foo;" }
      assert_equal "foo;\n", @env["tmp.js"].to_s

      File.open(filename, 'w') { |f| f.puts "bar;" }
      time = Time.now + 60
      File.utime(time, time, filename)
      assert_equal "bar;\n", @env["tmp.js"].to_s

      File.unlink(filename)
      assert_nil @env["tmp.js"]
    end
  end

  test "static asset is stale if its mtime is updated or deleted" do
    filename = File.join(fixture_path("default"), "tmp.png")

    sandbox filename do
      assert_nil @env["tmp.png"]

      File.open(filename, 'w') { |f| f.puts "foo" }
      assert_equal "foo\n", @env["tmp.png"].to_s

      File.open(filename, 'w') { |f| f.puts "bar" }
      time = Time.now + 60
      File.utime(time, time, filename)
      assert_equal "bar\n", @env["tmp.png"].to_s

      File.unlink(filename)
      assert_nil @env["tmp.png"]
    end
  end

  test "bundled asset cached if theres an error building it" do
    @env.cache = nil

    filename = File.join(fixture_path("default"), "tmp.coffee")

    sandbox filename do
      File.open(filename, 'w') { |f| f.puts "-->" }
      assert_raises(ExecJS::RuntimeError) do
        @env["tmp.js"].to_s
      end

      File.open(filename, 'w') { |f| f.puts "->" }
      time = Time.now + 60
      File.utime(time, time, filename)
      assert_equal "(function() {\n  (function() {});\n\n}).call(this);\n", @env["tmp.js"].to_s
    end
  end

  test "seperate contexts classes for each instance" do
    e1 = new_environment
    e2 = new_environment

    assert_raises(NameError) { e1.context_class.instance_method(:foo) }
    assert_raises(NameError) { e2.context_class.instance_method(:foo) }

    e1.context_class.class_eval do
      def foo; end
    end

    e1.context_class.instance_method(:foo)
    assert_raises(NameError) { e2.context_class.instance_method(:foo) }
  end

  test "registering engine adds to the environments extensions" do
    assert !@env.engines[".foo"]
    assert !@env.extensions.include?(".foo")

    @env.register_engine ".foo", Tilt::StringTemplate

    assert @env.engines[".foo"]
    assert @env.extensions.include?(".foo")
  end

  test "seperate engines for each instance" do
    e1 = new_environment
    e2 = new_environment

    assert_nil e1.engines[".foo"]
    assert_nil e2.engines[".foo"]

    e1.register_engine ".foo", Tilt::StringTemplate

    assert e1.engines[".foo"]
    assert_nil e2.engines[".foo"]
  end

  test "disabling default directive preprocessor" do
    @env.unregister_preprocessor('application/javascript', Sprockets::DirectiveProcessor)
    assert_equal "// =require \"notfound\"\n;\n", @env["missing_require.js"].to_s
  end
end

class TestIndex < Sprockets::TestCase
  include EnvironmentTests

  def new_environment
    Sprockets::Environment.new(".") do |env|
      env.append_path(fixture_path('default'))
      env.cache = {}
      yield env if block_given?
    end.index
  end

  def setup
    @env = new_environment
  end

  test "does not allow new mime types to be added" do
    assert_raises TypeError do
      @env.register_mime_type "application/javascript", ".jst"
    end
  end

  test "change in environment mime types does not affect index" do
    env = Sprockets::Environment.new(".")
    env.register_mime_type "application/javascript", ".jst"
    index = env.index

    assert_equal "application/javascript", index.mime_types("jst")
    env.register_mime_type nil, ".jst"
    assert_equal "application/javascript", index.mime_types("jst")
  end

  test "does not allow new bundle processors to be added" do
    assert_raises TypeError do
      @env.register_bundle_processor 'text/css', WhitespaceCompressor
    end
  end

  test "does not allow bundle processors to be removed" do
    assert_raises TypeError do
      @env.unregister_bundle_processor 'text/css', WhitespaceCompressor
    end
  end

  test "change in environment bundle_processors does not affect index" do
    env = Sprockets::Environment.new(".")
    index = env.index

    assert !index.bundle_processors('text/css').include?(WhitespaceCompressor)
    env.register_bundle_processor 'text/css', WhitespaceCompressor
    assert !index.bundle_processors('text/css').include?(WhitespaceCompressor)
  end

  test "does not allow css compressor to be changed" do
    assert_raises TypeError do
      @env.css_compressor = WhitespaceCompressor
    end
  end

  test "does not allow js compressor to be changed" do
    assert_raises TypeError do
      @env.js_compressor = WhitespaceCompressor
    end
  end

  test "change in environment engines does not affect index" do
    env = Sprockets::Environment.new
    index = env.index

    assert_nil env.engines[".foo"]
    assert_nil index.engines[".foo"]

    env.register_engine ".foo", Tilt::StringTemplate

    assert env.engines[".foo"]
    assert_nil index.engines[".foo"]
  end
end
