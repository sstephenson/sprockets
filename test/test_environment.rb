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
    assert_equal "application/javascript", @env.mime_types[".js"]
    assert_equal "text/css", @env.mime_types[".css"]
    assert_equal nil, @env.mime_types[".foo"]
  end

  test "lookup bundle processors" do
    assert_equal 1, @env.bundle_processors('application/javascript').size
    assert_equal 2, @env.bundle_processors('text/css').size
  end

  test "lookup compressors" do
    silence_warnings do
      require 'sprockets/sass_compressor'
    end
    assert_equal 'Sprockets::SassCompressor', @env.compressors['text/css'][:sass].name
    assert_equal 'Sprockets::UglifierCompressor', @env.compressors['application/javascript'][:uglifier].name
  end

  test "resolve absolute path in environment" do
    assert_equal fixture_path('default/gallery.js'),
      @env.resolve(fixture_path('default/gallery.js'))
    assert_equal fixture_path('default/coffee/foo.coffee'),
      @env.resolve(fixture_path('default/coffee/foo.coffee'))
    assert_equal fixture_path('default/jquery.tmpl.min.js'),
      @env.resolve(fixture_path('default/jquery.tmpl.min.js'))

    assert_equal fixture_path('default/gallery.css.erb'),
      @env.resolve(fixture_path('default/gallery'))
    assert_equal fixture_path('default/gallery.js'),
      @env.resolve(fixture_path('default/gallery'), content_type: 'application/javascript')
    assert_equal fixture_path('default/coffee/foo.coffee'),
      @env.resolve(fixture_path('default/coffee/foo'))
    assert_equal fixture_path('default/jquery.tmpl.min.js'),
      @env.resolve(fixture_path('default/jquery.tmpl.min'))
    assert_equal fixture_path('default/gallery.css.erb'),
      @env.resolve(fixture_path('default/gallery.css'))
    assert_equal fixture_path('default/gallery.css.erb'),
      @env.resolve(fixture_path('default/gallery'), content_type: 'text/css')

    assert_equal fixture_path('default/manifest.js.yml'),
      @env.resolve(fixture_path('default/manifest.js.yml'))
    assert_equal fixture_path('default/manifest.js.yml'),
      @env.resolve(fixture_path('default/manifest.js.yml'), content_type: 'text/yaml')

    assert_raises(Sprockets::FileNotFound) do
      @env.resolve(fixture_path('default/manifest.js.yml'), content_type: 'application/javascript')
    end
    assert_raises(Sprockets::FileNotFound) do
      @env.resolve(fixture_path('default/jquery.tmpl'))
    end
    assert_raises(Sprockets::FileNotFound) do
      @env.resolve(fixture_path('default/jquery'))
    end

    assert_equal fixture_path('default/gallery.js'),
      @env.resolve(fixture_path('default/gallery.js'), content_type: 'application/javascript')
    assert_equal fixture_path('default/coffee/foo.coffee'),
      @env.resolve(fixture_path('default/coffee/foo.coffee'), content_type: 'application/javascript')
    assert_equal fixture_path('default/jquery.tmpl.min.js'),
      @env.resolve(fixture_path('default/jquery.tmpl.min.js'), content_type: 'application/javascript')

    refute @env.resolve_all("/bin/sh").first
    assert_raises(Sprockets::FileOutsidePaths) do
      @env.resolve("/bin/sh")
    end

    refute @env.resolve_all(fixture_path('default/gallery.js'), content_type: 'text/css').first
    assert_raises(Sprockets::FileNotFound) do
      @env.resolve(fixture_path('default/gallery.js'), content_type: 'text/css')
    end

    refute @env.resolve_all(fixture_path('default/coffee/foo.coffee'), content_type: 'text/css').first
    assert_raises(Sprockets::FileNotFound) do
      @env.resolve(fixture_path('default/coffee/foo.coffee'), content_type: 'text/css')
    end

    refute @env.resolve_all(fixture_path('default/gallery.foo')).first
    assert_raises(Sprockets::FileNotFound) do
      @env.resolve(fixture_path('default/gallery.foo'))
    end
  end

  test "resolve in environment" do
    assert_equal fixture_path('default/gallery.js'),
      @env.resolve("gallery.js")
    assert_equal fixture_path('default/gallery.js'),
      @env.resolve(Pathname.new("gallery.js"))
    assert_equal fixture_path('default/coffee/foo.coffee'),
      @env.resolve("coffee/foo.js")
    assert_equal fixture_path('default/jquery.tmpl.min.js'),
      @env.resolve("jquery.tmpl.min")
    assert_equal fixture_path('default/jquery.tmpl.min.js'),
      @env.resolve("jquery.tmpl.min.js")
    assert_equal fixture_path('default/manifest.js.yml'),
      @env.resolve('manifest.js.yml')

    refute @env.resolve_all("null").first
    assert_raises(Sprockets::FileNotFound) do
      @env.resolve("null")
    end
  end

  test "resolve content type in environment" do
    assert_equal fixture_path('default/gallery.js'),
      @env.resolve("gallery.js")
    assert_equal fixture_path('default/gallery.js'),
      @env.resolve("gallery.js", content_type: "application/javascript")
    assert_equal fixture_path('default/gallery.js'),
      @env.resolve("gallery", content_type: "application/javascript")
    assert_equal fixture_path('default/coffee/foo.coffee'),
      @env.resolve('coffee/foo', content_type: 'application/javascript')
    assert_equal fixture_path('default/coffee/foo.coffee'),
      @env.resolve('coffee/foo.coffee', content_type: 'application/javascript')
    assert_equal fixture_path('default/jquery.tmpl.min.js'),
      @env.resolve("jquery.tmpl.min", content_type: 'application/javascript')
    assert_equal fixture_path('default/jquery.tmpl.min.js'),
      @env.resolve("jquery.tmpl.min.js", content_type: 'application/javascript')
    assert_equal fixture_path('default/manifest.js.yml'),
      @env.resolve('manifest.js.yml', content_type: 'text/yaml')

    assert_raises(Sprockets::FileNotFound) do
      @env.resolve('manifest.js.yml', content_type: 'application/javascript')
    end

    assert_raises(Sprockets::FileNotFound) do
      @env.resolve("gallery.js", content_type: "text/css")
    end
  end

  test "resolve bower special case" do
    assert_equal fixture_path('default/bower/bower.json'),
      @env.resolve("bower/bower.json")
    assert_equal fixture_path('default/bower/main.js'),
      @env.resolve("bower")
    assert_equal fixture_path('default/bower/main.js'),
      @env.resolve("bower.js")
    assert_equal fixture_path('default/bower/main.js'),
      @env.resolve("bower", content_type: 'application/javascript')
    assert_equal fixture_path('default/bower/main.js'),
      @env.resolve("bower.js", content_type: 'application/javascript')
    assert_raises(Sprockets::FileNotFound) do
      @env.resolve("bower.css", content_type: 'text/css')
    end

    assert_equal fixture_path('default/qunit/qunit.js'),
      @env.resolve("qunit")
    assert_equal fixture_path('default/qunit/qunit.js'),
      @env.resolve("qunit.js")
    assert_equal fixture_path('default/qunit/qunit.js'),
      @env.resolve("qunit", content_type: 'application/javascript')
    assert_equal fixture_path('default/qunit/qunit.js'),
      @env.resolve("qunit.js", content_type: 'application/javascript')
    assert_equal fixture_path('default/qunit/qunit.css'),
      @env.resolve("qunit.css")
    assert_equal fixture_path('default/qunit/qunit.css'),
      @env.resolve("qunit", content_type: 'text/css')
    assert_equal fixture_path('default/qunit/qunit.css'),
      @env.resolve("qunit.css", content_type: 'text/css')

    assert_equal fixture_path('default/rails/rails.coffee'),
      @env.resolve("rails")
    assert_equal fixture_path('default/rails/rails.coffee'),
      @env.resolve("rails.js")
    assert_equal fixture_path('default/rails/rails.coffee'),
      @env.resolve("rails", content_type: 'application/javascript')
    assert_equal fixture_path('default/rails/rails.coffee'),
      @env.resolve("rails.js", content_type: 'application/javascript')
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

  test "find bower.json in directory" do
    assert_equal "var bower;\n", @env["bower.js"].to_s
  end

  test "find multiple bower.json in directory" do
    assert_equal "var qunit;\n", @env["qunit.js"].to_s
    assert_equal ".qunit {}\n", @env["qunit.css"].to_s
  end

  test "find asset by etag" do
    asset = @env.find_asset("gallery.js")
    assert @env.find_asset("gallery.js", if_match: asset.etag)
    refute @env.find_asset("gallery.js", if_match: "0000000000000000000000000000000000000000")
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
    assert_raises Sprockets::FileOutsidePaths do
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

  FILES_IN_PATH = 42

  test "iterate over each logical path" do
    paths = []
    paths = @env.logical_paths.to_a.map(&:first)
    assert_equal FILES_IN_PATH, paths.length
    assert_equal paths.size, paths.uniq.size, "has duplicates"

    assert paths.include?("application.js")
    assert paths.include?("coffee/foo.js")
    assert paths.include?("coffee.js")
    assert !paths.include?("coffee")
  end

  test "iterate over each logical path and filename" do
    paths = []
    filenames = []
    @env.logical_paths.each do |logical_path, filename|
      paths << logical_path
      filenames << filename
    end
    assert_equal FILES_IN_PATH, paths.length
    assert_equal paths.size, paths.uniq.size, "has duplicates"

    assert paths.include?("application.js")
    assert paths.include?("coffee/foo.js")
    assert paths.include?("coffee.js")
    assert !paths.include?("coffee")

    assert filenames.any? { |p| p =~ /application.js.coffee/ }
  end

  test "CoffeeScript files are compiled in a closure" do
    script = @env["coffee"].to_s
    assert_equal "undefined", ExecJS.exec(script)
  end
end

class WhitespaceProcessor
  def self.call(input)
    input[:data].gsub(/\s+/, "")
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
    assert !@env.mime_types[".jst"]
    @env.register_mime_type("application/javascript", "jst")
    assert_equal "application/javascript", @env.mime_types[".jst"]
  end

  test "register bundle processor" do
    old_size = @env.bundle_processors('text/css').size
    @env.register_bundle_processor 'text/css', WhitespaceProcessor
    assert_equal old_size+1, @env.bundle_processors('text/css').size
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
    old_size = Sprockets.bundle_processors('text/css').size
    Sprockets.register_bundle_processor 'text/css', WhitespaceProcessor
    assert_equal old_size+1, Sprockets.bundle_processors('text/css').size

    env = new_environment
    assert_equal old_size+1, env.bundle_processors('text/css').size

    Sprockets.unregister_bundle_processor 'text/css', WhitespaceProcessor
    assert_equal old_size, Sprockets.bundle_processors('text/css').size
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

  test "setting js compressor to template handler" do
    assert_nil @env.js_compressor
    @env.js_compressor = Sprockets::UglifierCompressor
    assert_equal Sprockets::UglifierCompressor, @env.js_compressor
    @env.js_compressor = nil
    assert_nil @env.js_compressor
  end

  test "setting css compressor to template handler" do
    silence_warnings do
      require 'sprockets/sass_compressor'
    end
    assert_nil @env.css_compressor
    @env.css_compressor = Sprockets::SassCompressor
    assert_equal Sprockets::SassCompressor, @env.css_compressor
    @env.css_compressor = nil
    assert_nil @env.css_compressor
  end

  test "setting js compressor to sym" do
    assert_nil @env.js_compressor
    @env.js_compressor = :uglifier
    assert_equal 'Sprockets::UglifierCompressor', @env.js_compressor.name
    @env.js_compressor = nil
    assert_nil @env.js_compressor
  end

  test "setting css compressor to sym" do
    silence_warnings do
      require 'sprockets/sass_compressor'
    end
    assert_nil @env.css_compressor
    @env.css_compressor = :sass
    assert_equal 'Sprockets::SassCompressor', @env.css_compressor.name
    @env.css_compressor = nil
    assert_nil @env.css_compressor
  end

  test "changing version doesn't affect the assets digest" do
    old_asset_digest = @env["gallery.js"].digest
    @env.version = 'v2'
    assert old_asset_digest == @env["gallery.js"].digest
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
      begin
        @env["tmp.js"].to_s
      rescue ExecJS::Error => e
        assert e
      else
        flunk "nothing raised"
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

  test "seperate engines for each instance" do
    e1 = new_environment
    e2 = new_environment

    assert_nil e1.engines[".foo"]
    assert_nil e2.engines[".foo"]

    e1.register_engine ".foo", Sprockets::ERBTemplate

    assert e1.engines[".foo"]
    assert_nil e2.engines[".foo"]
  end

  test "disabling default directive preprocessor" do
    @env.unregister_preprocessor('application/javascript', Sprockets::DirectiveProcessor)
    assert_equal "// =require \"notfound\"\n;\n", @env["missing_require.js"].to_s
  end

  test "verify all absolute paths" do
    env = new_environment
    Dir.entries(Sprockets::TestCase::FIXTURE_ROOT).each do |dir|
      unless %w( . ..).include?(dir)
        env.append_path(fixture_path(dir))
      end
    end

    # TODO: Expose environment helper for this
    env.paths.each do |root|
      env.stat_tree(root).each do |filename, stat|
        next unless stat.file?

        assert_equal filename, env.resolve_all(filename).first,
          "Expected #{filename.inspect} to resolve to itself"
      end
    end
  end

  test "verify all logical paths" do
    env = new_environment
    Dir.entries(Sprockets::TestCase::FIXTURE_ROOT).each do |dir|
      unless %w( . ..).include?(dir)
        env.append_path(fixture_path(dir))
      end
    end

    env.logical_paths.each do |logical_path, filename|
      assert_equal filename, env.resolve_all(logical_path).first,
        "Expected #{logical_path.inspect} to resolve to #{filename}"
    end
  end
end

class TestCached < Sprockets::TestCase
  include EnvironmentTests

  def new_environment
    Sprockets::Environment.new(".") do |env|
      env.append_path(fixture_path('default'))
      env.cache = {}
      yield env if block_given?
    end.cached
  end

  def setup
    @env = new_environment
  end

  test "does not allow new mime types to be added" do
    assert_raises TypeError do
      @env.register_mime_type "application/javascript", ".jst"
    end
  end

  test "change in environment mime types does not affect cache" do
    env = Sprockets::Environment.new(".")
    env.register_mime_type "application/javascript", ".jst"
    cached = env.cached

    assert_equal "application/javascript", cached.mime_types[".jst"]
    env.register_mime_type nil, ".jst"
    assert_equal "application/javascript", cached.mime_types[".jst"]
  end

  test "does not allow new bundle processors to be added" do
    assert_raises TypeError do
      @env.register_bundle_processor 'text/css', WhitespaceProcessor
    end
  end

  test "does not allow bundle processors to be removed" do
    assert_raises TypeError do
      @env.unregister_bundle_processor 'text/css', WhitespaceProcessor
    end
  end

  test "change in environment bundle_processors does not affect cache" do
    env = Sprockets::Environment.new(".")
    cached = env.cached

    assert !cached.bundle_processors('text/css').include?(WhitespaceProcessor)
    env.register_bundle_processor 'text/css', WhitespaceProcessor
    assert !cached.bundle_processors('text/css').include?(WhitespaceProcessor)
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

  test "change in environment engines does not affect cache" do
    env = Sprockets::Environment.new
    cached = env.cached

    assert_nil env.engines[".foo"]
    assert_nil cached.engines[".foo"]

    env.register_engine ".foo", Sprockets::ERBTemplate

    assert env.engines[".foo"]
    assert_nil cached.engines[".foo"]
  end
end
