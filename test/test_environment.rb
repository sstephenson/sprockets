require 'sprockets_test'
require 'rack/mock'

module EnvironmentTests
  def self.test(name, &block)
    define_method("test #{name.inspect}", &block)
  end

  test "working directory is the default root" do
    assert_equal Dir.pwd, @env.root
  end

  test "active css compressor" do
    assert_nil @env.css_compressor
  end

  test "active js compressor" do
    assert_nil @env.js_compressor
  end

  test "current static root" do
    assert_equal fixture_path("public"), @env.static_root.to_s
  end

  test "paths" do
    assert_equal [fixture_path("default")], @env.paths.to_a
  end

  test "extensions" do
    ["coffee", "erb", "less", "sass", "scss", "str", "css", "js"].each do |ext|
      assert @env.extensions.to_a.include?(".#{ext}")
    end
  end

  test "engine extensions" do
    ["coffee", "erb", "less", "sass", "scss", "str"].each do |ext|
      assert @env.engines.extensions.include?(".#{ext}")
    end
    ["css", "js"].each do |ext|
      assert !@env.engines.extensions.include?(".#{ext}")
    end
  end

  test "resolve in environment" do
    assert_equal fixture_path('default/gallery.js'),
      @env.resolve("gallery.js").to_s
  end

  test "missing file raises an exception" do
    assert_raises(Sprockets::FileNotFound) do
      @env.resolve("null")
    end
  end

  test "resolve ignores static root" do
    assert_raises(Sprockets::FileNotFound) do
      @env.resolve("compiled.js")
    end
  end

  test "find concatenated asset in environment" do
    assert_equal "var Gallery = {};\n", @env["gallery.js"].to_s
  end

  test "find concatenated asset with leading slash in environment" do
    assert_equal "var Gallery = {};\n", @env["/gallery.js"].to_s
  end

  test "find static asset in environment" do
    assert_equal "Hello world\n", @env["hello.txt"].to_s
  end

  test "find static asset with leading slash in environment" do
    assert_equal "Hello world\n", @env["/hello.txt"].to_s
  end

  test "find compiled asset in static root" do
    assert_equal "(function() {\n  application.boot();\n})();\n",
      @env["compiled.js"].to_s
  end

  test "find compiled asset with leading slash in static root" do
    assert_equal "(function() {\n  application.boot();\n})();\n",
      @env["/compiled.js"].to_s
  end

  test "find compiled asset in static root is StaticAsset" do
    assert_equal Sprockets::StaticAsset, @env["compiled.js"].class
  end

  test "find asset with digest" do
    assert_equal "Hello world\n",
      @env["hello-f0ef7081e1539ac00ef5b761b4fb01b3.txt"].to_s
  end

  test "find asset with invalid digest" do
    assert_nil @env["hello-ffffffff.txt"]
  end

  test "find index.js in directory" do
    assert_equal "var A;\nvar B;\n", @env["mobile.js"].to_s
  end

  test "find index.css in directory" do
    assert_equal ".c {}\n.d {}\n/*\n */\n\n", @env["mobile.css"].to_s
  end

  test "find static directory returns nil" do
    assert_nil @env["images"]
  end

  test "find compiled asset with filename digest in static root" do
    assert_equal "(function() {\n  application.boot();\n})();\n",
      @env["compiled-digest.js"].to_s
    assert_equal "(function() {\n  application.boot();\n})();\n",
      @env["compiled-digest-0aa2105d29558f3eb790d411d7d8fb66.js"].to_s
    assert_equal "(function() {})();\n",
      @env["compiled-digest-1c41eb0cf934a0c76babe875f982f9d1.js"].to_s
  end

  test "find asset when static root doesn't exist" do
    env = new_environment { |e| e.static_root = fixture_path('missing') }
    assert_equal "var Gallery = {};\n", env["gallery.js"].to_s
  end

  test "missing asset returns nil" do
    assert_equal nil, @env["missing.js"]
  end

  test "asset with missing requires raises an exception" do
    assert_raises Sprockets::FileNotFound do
      @env["missing_require.js"]
    end
  end

  test "lookup asset digest" do
    assert_equal "f1598cfbaf2a26f20367e4046957f6e0",
      @env["gallery.js"].digest
  end

  test "path for asset" do
    assert_equal "/gallery-f1598cfbaf2a26f20367e4046957f6e0.js", @env.path("gallery.js")
    assert_equal "/gallery.js", @env.path("gallery.js", false)
    assert_equal "/gallery-f1598cfbaf2a26f20367e4046957f6e0.js", @env.path("/gallery.js")
    assert_equal "/assets/gallery-f1598cfbaf2a26f20367e4046957f6e0.js",
      @env.path("gallery.js", true, "/assets")
  end

  test "url for asset" do
    env = Rack::MockRequest.env_for("/")

    assert_equal "http://example.org/gallery-f1598cfbaf2a26f20367e4046957f6e0.js",
      @env.url(env, "gallery.js")
    assert_equal "http://example.org/gallery.js",
      @env.url(env, "gallery.js", false)
    assert_equal "http://example.org/gallery-f1598cfbaf2a26f20367e4046957f6e0.js",
      @env.url(env, "/gallery.js")
    assert_equal "http://example.org/assets/gallery-f1598cfbaf2a26f20367e4046957f6e0.js",
      @env.url(env, "gallery.js", true, "assets")
  end

  test "missing path for asset" do
    assert_equal "/missing.js", @env.path("missing.js")
  end

  test "precompile" do
    filename = fixture_path("public/gallery-f1598cfbaf2a26f20367e4046957f6e0.js")
    begin
      assert !File.exist?(filename)
      @env.precompile("gallery.js")
      assert File.exist?(filename)
    ensure
      File.unlink(filename) if File.exist?(filename)
    end
  end

  test "precompile glob" do
    dirname = fixture_path("public/mobile")

    begin
      assert !File.exist?(dirname)
      @env.precompile("mobile/*")

      assert File.exist?(dirname)
      assert File.exist?(File.join(dirname, "a-172ecf751b024e2c68b1da265523b202.js"))
      assert File.exist?(File.join(dirname, "b-5e5f944f87f43e1ddec5c8dc109e5f8d.js"))
      assert File.exist?(File.join(dirname, "c-4127d837671de30f7e9cb8e9bec82285.css"))
    ensure
      FileUtils.rm_rf(dirname)
    end
  end

  test "precompile regexp" do
    dirname = fixture_path("public/mobile")

    begin
      assert !File.exist?(dirname)
      @env.precompile(/mobile\/.*/)

      assert File.exist?(dirname)
      assert File.exist?(File.join(dirname, "a-172ecf751b024e2c68b1da265523b202.js"))
      assert File.exist?(File.join(dirname, "b-5e5f944f87f43e1ddec5c8dc109e5f8d.js"))
      assert File.exist?(File.join(dirname, "c-4127d837671de30f7e9cb8e9bec82285.css"))
    ensure
      FileUtils.rm_rf(dirname)
    end
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
    env = Sprockets::Environment.new(".")
    env.paths << fixture_path('default')
    env.static_root = fixture_path('public')
    yield env if block_given?
    env
  end

  def setup
    @env = new_environment
  end

  test "changing static root expires old assets" do
    assert @env["compiled.js"]
    @env.static_root = nil
    assert_nil @env["compiled.js"]
  end

  test "changing css compressor expires old assets" do
    assert_equal ".gallery {\n  color: red;\n}\n", @env["gallery.css"].to_s
    @env.css_compressor = WhitespaceCompressor
    assert_equal ".gallery{color:red;}", @env["gallery.css"].to_s
  end

  test "changing js compressor expires old assets" do
    assert_equal "var Gallery = {};\n", @env["gallery.js"].to_s
    @env.js_compressor = WhitespaceCompressor
    assert_equal "varGallery={};", @env["gallery.js"].to_s
  end

  test "changing paths expires old assets" do
    assert @env["gallery.css"]
    @env.paths.clear
    assert_nil @env["gallery.css"]
  end

  test "changing extensions expires old assets" do
    assert @env["gallery.css"]
    @env.extensions.clear
    assert_nil @env["gallery.css"]
  end

  test "concatenated asset is stale if its mtime is updated or deleted" do
    filename = File.join(fixture_path("default"), "tmp.js")

    begin
      assert_nil @env["tmp.js"]

      File.open(filename, 'w') { |f| f.puts "foo" }
      assert_equal "foo\n", @env["tmp.js"].to_s

      File.open(filename, 'w') { |f| f.puts "bar" }
      time = Time.now + 60
      File.utime(time, time, filename)
      assert_equal "bar\n", @env["tmp.js"].to_s

      File.unlink(filename)
      assert_nil @env["tmp.js"]
    ensure
      File.unlink(filename) if File.exist?(filename)
      assert !File.exist?(filename)
    end
  end

  test "static asset is stale if its mtime is updated or deleted" do
    filename = File.join(fixture_path("default"), "tmp.png")

    begin
      assert_nil @env["tmp.png"]

      File.open(filename, 'w') { |f| f.puts "foo" }
      assert_equal "foo\n", @env["tmp.png"].to_s

      File.open(filename, 'w') { |f| f.puts "bar" }
      time = Time.now + 60
      File.utime(time, time, filename)
      assert_equal "bar\n", @env["tmp.png"].to_s

      File.unlink(filename)
      assert_nil @env["tmp.png"]
    ensure
      File.unlink(filename) if File.exist?(filename)
      assert !File.exist?(filename)
    end
  end

  test "seperate contexts classes for each instance" do
    e1 = new_environment
    e2 = new_environment

    assert_raises(NameError) { e1.context.instance_method(:foo) }
    assert_raises(NameError) { e2.context.instance_method(:foo) }

    e1.context.class_eval do
      def foo; end
    end

    assert_nothing_raised(NameError) { e1.context.instance_method(:foo) }
    assert_raises(NameError) { e2.context.instance_method(:foo) }
  end

  test "registering engine adds to the environments extensions" do
    assert !@env.engines[".foo"]
    assert !@env.extensions.include?(".foo")

    @env.engines.register ".foo", Tilt::StringTemplate

    assert @env.engines[".foo"]
    assert @env.extensions.include?(".foo")
  end

  test "seperate engines for each instance" do
    e1 = new_environment
    e2 = new_environment

    assert_nil e1.engines[".foo"]
    assert_nil e2.engines[".foo"]

    e1.engines.register ".foo", Tilt::StringTemplate

    assert e1.engines[".foo"]
    assert_nil e2.engines[".foo"]
  end

  test "disabling default directive preprocessor" do
    @env.engines.pre_processors.delete(Sprockets::DirectiveProcessor)
    assert_equal "// =require \"notfound\"\n", @env["missing_require.js"].to_s
  end

  test "adding ERB postprocessor to all assets" do
    @env.engines.post_processors.push(Tilt::ERBTemplate)
    assert_equal "var Interpolation = 2;\n", @env["interpolation.js"].to_s
  end
end

class TestEnvironmentIndex < Sprockets::TestCase
  include EnvironmentTests

  def new_environment
    env = Sprockets::Environment.new(".")
    env.paths << fixture_path('default')
    env.static_root = fixture_path('public')
    yield env if block_given?
    env.index
  end

  def setup
    @env = new_environment
  end

  test "does not allow static root to be changed" do
    assert !@env.respond_to?(:static_root=)
  end

  test "change in environment static root does not affect index" do
    env = Sprockets::Environment.new(".")
    env.static_root = fixture_path('public')
    index = env.index

    assert_equal fixture_path('public'), index.static_root.to_s
    env.static_root = fixture_path('static')
    assert_equal fixture_path('public'), index.static_root.to_s
  end

  test "does not allow css compressor to be changed" do
    assert !@env.respond_to?(:css_compressor=)
  end

  test "change in environment css compressor does not affect index" do
    env = Sprockets::Environment.new(".")
    env.css_compressor = WhitespaceCompressor
    index = env.index

    assert_equal WhitespaceCompressor, index.css_compressor
    env.css_compressor = nil
    assert_equal WhitespaceCompressor, index.css_compressor
  end

  test "does not allow js compressor to be changed" do
    assert !@env.respond_to?(:js_compressor=)
  end

  test "change in environment js compressor does not affect index" do
    env = Sprockets::Environment.new(".")
    env.js_compressor = WhitespaceCompressor
    index = env.index

    assert_equal WhitespaceCompressor, index.js_compressor
    env.js_compressor = nil
    assert_equal WhitespaceCompressor, index.js_compressor
  end

  test "change in environment engines does not affect index" do
    env = Sprockets::Environment.new
    index = env.index

    assert_nil env.engines[".foo"]
    assert_nil index.engines[".foo"]

    env.engines.register ".foo", Tilt::StringTemplate

    assert env.engines[".foo"]
    assert_nil index.engines[".foo"]
  end
end
