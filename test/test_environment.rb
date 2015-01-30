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
    asset = @env["goodbye.js"]
    context = ExecJS.compile(asset.to_s)
    assert_equal "Goodbye world\n", context.call("JST['goodbye']", :name => "world")
  end

  test "ejs templates" do
    assert asset = @env["hello.js"]
    context = ExecJS.compile(asset.to_s)
    assert_equal "hello: world\n", context.call("JST['hello']", :name => "world")
  end

  test "another ejs templates" do
    assert asset = @env["hello2.js"]
    context = ExecJS.compile(asset.to_s)
    assert_equal "hello2: world\n", context.call("JST2['hello2']", :name => "world")
  end

  test "angular templates" do
    assert asset = @env["ng-view.js"]
    assert_equal <<-JS, asset.to_s
$app.run(function($templateCache) {
  $templateCache.put('ng-view.html', "<div ng-view></div>");
});
    JS
  end

  test "asset_data_uri helper" do
    assert asset = @env["with_data_uri.css"]
    assert_equal "body {\n  background-image: url(data:image/gif;base64,R0lGODlhAQABAIAAAP%2F%2F%2FwAAACH5BAAAAAAALAAAAAABAAEAAAICRAEAOw%3D%3D) no-repeat;\n}\n", asset.to_s
  end

  test "lookup bundle processors" do
    assert_equal 1, @env.bundle_processors['application/javascript'].size
    assert_equal 1, @env.bundle_processors['text/css'].size
  end

  test "find asset with accept type" do
    assert asset = @env.find_asset("gallery.js", accept: '*/*')
    assert_equal fixture_path('default/gallery.js'), asset.filename

    assert asset = @env.find_asset("gallery", accept: 'application/javascript')
    assert_equal fixture_path('default/gallery.js'), asset.filename

    assert asset = @env.find_asset("gallery", accept: 'application/javascript, text/css')
    assert_equal fixture_path('default/gallery.js'), asset.filename

    assert asset = @env.find_asset("gallery.js", accept: 'application/javascript')
    assert_equal fixture_path('default/gallery.js'), asset.filename

    assert asset = @env.find_asset("gallery", accept: 'text/css, application/javascript')
    assert_equal fixture_path('default/gallery.css.erb'), asset.filename

    assert asset = @env.find_asset("coffee/foo", accept: "application/javascript")
    assert_equal fixture_path('default/coffee/foo.coffee'), asset.filename

    assert asset = @env.find_asset("coffee/foo.js", accept: "application/javascript")
    assert_equal fixture_path('default/coffee/foo.coffee'), asset.filename

    assert asset = @env.find_asset("jquery.tmpl.min", accept: 'application/javascript')
    assert_equal fixture_path('default/jquery.tmpl.min.js'), asset.filename

    assert asset = @env.find_asset("jquery.tmpl.min.js", accept: 'application/javascript')
    assert_equal fixture_path('default/jquery.tmpl.min.js'), asset.filename

    assert asset = @env.find_asset('manifest.js.yml', accept: 'text/yaml')
    assert_equal fixture_path('default/manifest.js.yml'), asset.filename

    assert asset = @env.find_asset('manifest.js.yml', accept: 'text/css, */*')
    assert_equal fixture_path('default/manifest.js.yml'), asset.filename

    refute @env.find_asset("gallery.js", accept: "text/css")
    refute @env.find_asset(fixture_path('default/gallery.js'), accept: "text/css")

    refute @env.find_asset('manifest.js.yml', accept: 'application/javascript')
  end

  test "find all linked assets" do
    assert assets = @env.find_all_linked_assets("missing.js").to_a
    assert_equal 0, assets.length

    assert assets = @env.find_all_linked_assets("gallery.js").to_a
    assert_equal 1, assets.length
    assert_equal @env["gallery.js"], assets[0]

    assert assets = @env.find_all_linked_assets("gallery-link.js").to_a
    assert_equal 2, assets.length
    assert_equal @env["gallery-link.js"], assets[0]
    assert_equal @env["gallery.js"], assets[1]

    assert assets = @env.find_all_linked_assets("explore-link.js").to_a
    assert_equal 3, assets.length
    assert_equal @env["explore-link.js"], assets[0]
    assert_equal @env["gallery-link.js"], assets[1]
    assert_equal @env["gallery.js"], assets[2]
  end

  test "html subresource links" do
    assert asset = @env["homepage-links.html"]
    assert_equal "text/html", asset.content_type
    assert asset.to_s.match(/gallery-[a-z0-9]+\.css/)
    assert asset.to_s.match(/gallery-[a-z0-9]+\.js/)
    assert asset.links.include?(@env["gallery.css"].uri)
    assert asset.links.include?(@env["gallery.js"].uri)
  end

  test "web component assets" do
    assert asset = @env["menu/menu.html"]
    assert_equal "text/html", asset.content_type
    assert_equal "<menu></menu>\n", asset.to_s

    assert asset = @env["menu/menu.js"]
    assert_equal "application/javascript", asset.content_type
    assert_equal "$.fn.menu = {};\n", asset.to_s

    assert asset = @env["menu/menu.css"]
    assert_equal "text/css", asset.content_type
    assert_equal ".menu {}\n", asset.to_s
  end

  test "explicit bower.json access returns json file" do
    assert_equal fixture_path('default/bower/bower.json'),
      @env["bower/bower.json"].filename
  end

  test "find default bower main" do
    assert_equal fixture_path('default/bower/main.js'),
      @env["bower"].filename
    assert_equal fixture_path('default/qunit/qunit.js'),
      @env["qunit"].filename
    assert_equal fixture_path('default/rails/rails.coffee'),
      @env["rails"].filename
  end

  test "find bower main by format extension" do
    assert_equal fixture_path('default/bower/main.js'),
      @env["bower.js"].filename
    refute @env.find_asset("bower.css")

    assert_equal fixture_path('default/qunit/qunit.js'),
      @env["qunit.js"].filename
    assert_equal fixture_path('default/qunit/qunit.css'),
      @env["qunit.css"].filename

    assert_equal fixture_path('default/rails/rails.coffee'),
      @env["rails.js"].filename

    assert_equal fixture_path('default/requirejs/require.js'),
      @env.find_asset("requirejs.js").filename
  end

  test "find bower main by content type" do
    assert_equal fixture_path('default/bower/main.js'),
      @env.find_asset("bower", accept: 'application/javascript').filename
    assert_equal fixture_path('default/bower/main.js'),
      @env.find_asset("bower.js", accept: 'application/javascript').filename

    assert_equal fixture_path('default/qunit/qunit.js'),
      @env.find_asset("qunit", accept: 'application/javascript').filename
    assert_equal fixture_path('default/qunit/qunit.js'),
      @env.find_asset("qunit.js", accept: 'application/javascript').filename
    assert_equal fixture_path('default/qunit/qunit.css'),
      @env.find_asset("qunit", accept: 'text/css').filename
    assert_equal fixture_path('default/qunit/qunit.css'),
      @env.find_asset("qunit.css", accept: 'text/css').filename

    assert_equal fixture_path('default/rails/rails.coffee'),
      @env.find_asset("rails", accept: 'application/javascript').filename
    assert_equal fixture_path('default/rails/rails.coffee'),
      @env.find_asset("rails.js", accept: 'application/javascript').filename

    assert_equal fixture_path('default/requirejs/require.js'),
      @env.find_asset("requirejs.js", accept: 'application/javascript').filename
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

  test "ignore index.min.js in directory" do
    refute @env["mobile-min.js"]
  end

  test "find bower.json in directory" do
    assert_equal "var bower;\n", @env["bower.js"].to_s
  end

  test "find multiple bower.json in directory" do
    assert_equal "var qunit;\n", @env["qunit.js"].to_s
    assert_equal ".qunit {}\n", @env["qunit.css"].to_s
  end

  test "find erb assets" do
    assert asset = @env.find_asset("erb/a")
    assert_equal "text/plain", asset.content_type

    assert asset = @env.find_asset("erb/b")
    assert_equal "text/plain", asset.content_type

    assert asset = @env.find_asset("erb/c")
    assert_equal "application/javascript", asset.content_type

    assert asset = @env.find_asset("erb/d")
    assert_equal "text/css", asset.content_type

    assert asset = @env.find_asset("erb/e")
    assert_equal "text/html", asset.content_type

    assert asset = @env.find_asset("erb/f")
    assert_equal "text/yaml", asset.content_type
  end

  test "es6 asset" do
    assert asset = @env.find_asset("future.js")
    assert_match(/var square/, asset.to_s)
    assert_match(/function/, asset.to_s)
  end

  test "find html builder asset" do
    assert asset = @env.find_asset("nokogiri-html.html")
    assert_equal "text/html", asset.content_type
    assert_equal <<-HTML, asset.to_s
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body><span class="bold">Hello world</span></body></html>
    HTML
  end

  test "find xml builder asset" do
    assert asset = @env.find_asset("nokogiri-xml.xml")
    assert_equal "application/xml", asset.content_type
    assert_equal <<-XML, asset.to_s
<?xml version="1.0"?>
<root>
  <products>
    <widget>
      <id>10</id>
      <name>Awesome widget</name>
    </widget>
  </products>
</root>
    XML
  end

  test "svg transformer for extension" do
    assert asset = @env.find_asset("logo.svg")
    assert_equal "image/svg+xml", asset.content_type
    assert_equal "logo.svg", asset.logical_path
    assert_equal [60, 115, 118, 103, 32, 119, 105, 100, 116, 104], asset.to_s[0, 10].bytes.to_a

    assert asset = @env.find_asset("logo.png")
    assert_equal "image/png", asset.content_type
    assert_equal "logo.png", asset.logical_path
    assert_equal [137, 80, 78, 71, 13, 10, 26, 10, 60, 115], asset.to_s[0, 10].bytes.to_a
  end

  test "svg transformer for accept" do
    assert asset = @env.find_asset("logo", accept: "image/svg+xml")
    assert_equal "image/svg+xml", asset.content_type
    assert_equal "logo.svg", asset.logical_path
    assert_equal [60, 115, 118, 103, 32, 119, 105, 100, 116, 104], asset.to_s[0, 10].bytes.to_a

    assert asset = @env.find_asset("logo", accept: "image/png")
    assert_equal "image/png", asset.content_type
    assert_equal "logo.png", asset.logical_path
    assert_equal [137, 80, 78, 71, 13, 10, 26, 10, 60, 115], asset.to_s[0, 10].bytes.to_a
  end

  test "full path svg transformer" do
    assert @env.find_asset(fixture_path("default/logo.svg"))
    refute @env.find_asset(fixture_path("default/logo.png"))
  end

  test "full path svg transformer for accept" do
    assert asset = @env.find_asset(fixture_path("default/logo.svg"), accept: "image/svg+xml")
    assert_equal "logo.svg", asset.logical_path
    assert_equal "image/svg+xml", asset.content_type
    assert_equal [60, 115, 118, 103, 32, 119, 105, 100, 116, 104], asset.to_s[0, 10].bytes.to_a

    assert asset = @env.find_asset(fixture_path("default/logo.svg"), accept: "image/png")
    assert_equal "image/png", asset.content_type
    assert_equal "logo.png", asset.logical_path
    assert_equal [137, 80, 78, 71, 13, 10, 26, 10, 60, 115], asset.to_s[0, 10].bytes.to_a
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
    refute @env[fixture_path("default/missing.js")]
  end

  test "asset filename outside of load paths" do
    path = File.expand_path("../../bin/sprockets", __FILE__)
    assert File.exist?(path), "#{path} didn't exist"

    refute @env[path]
  end

  test "non-existent asset filename outside of load paths" do
    path = File.expand_path("../../bin/sprockets2", __FILE__)
    refute File.exist?(path), "#{path} exists"

    refute @env[path]
  end

  test "can't require files outside the load path" do
    path = fixture_path("default/../asset/project.css")
    assert File.exist?(path)

    refute @env[path]
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
      @env.find_asset(fixture_path("default/gallery.js")).logical_path
    assert_equal "application.js",
      @env.find_asset(fixture_path("default/application.coffee"), accept: "application/javascript").logical_path
    assert_equal "mobile/a.js",
      @env.find_asset(fixture_path("default/mobile/a.js")).logical_path
  end

  test "mobile index logical path shorthand" do
    assert_equal "mobile.js",
      @env[fixture_path("default/mobile/index.js")].logical_path
    assert_equal "mobile-min/index.min.js",
      @env[fixture_path("default/mobile-min/index.min.js")].logical_path
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

  test "register bundle processor" do
    old_size = @env.bundle_processors['text/css'].size
    @env.register_bundle_processor 'text/css', WhitespaceProcessor
    assert_equal old_size+1, @env.bundle_processors['text/css'].size
  end

  test "register compressor" do
    assert !@env.compressors['text/css'][:whitespace]
    @env.register_compressor 'text/css', :whitespace, WhitespaceCompressor
    assert @env.compressors['text/css'][:whitespace]
  end

  test "register global bundle processor" do
    old_size = Sprockets.bundle_processors['text/css'].size
    Sprockets.register_bundle_processor 'text/css', WhitespaceProcessor
    assert_equal old_size+1, Sprockets.bundle_processors['text/css'].size

    env = new_environment
    assert_equal old_size+1, env.bundle_processors['text/css'].size

    Sprockets.unregister_bundle_processor 'text/css', WhitespaceProcessor
    assert_equal old_size, Sprockets.bundle_processors['text/css'].size
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

  test "pre/post processors on transformed asset" do
    @env.register_preprocessor 'image/svg+xml', proc { |input|
      { data: input[:data], test: Array(input[:metadata][:test]) + [:pre_svg] }
    }
    @env.register_preprocessor 'image/png', proc { |input|
      { data: input[:data], test: Array(input[:metadata][:test]) + [:pre_png] }
    }
    @env.register_postprocessor 'image/svg+xml', proc { |input|
      { data: input[:data], test: Array(input[:metadata][:test]) + [:post_svg] }
    }
    @env.register_postprocessor 'image/png', proc { |input|
      { data: input[:data], test: Array(input[:metadata][:test]) + [:post_png] }
    }

    assert asset = @env.find_asset("logo.svg")
    assert_equal "image/svg+xml", asset.content_type
    assert_equal [:pre_svg, :post_svg], asset.metadata[:test]

    assert asset = @env.find_asset("logo.png")
    assert_equal "image/png", asset.content_type
    assert_equal [:pre_svg, :post_svg, :pre_png, :post_png], asset.metadata[:test]
  end

  test "access selector count metadata" do
    assert asset = @env.find_asset("mobile.css")
    assert_equal 2, asset.metadata[:selector_count]
  end

  test "changing version doesn't affect the assets digest" do
    old_asset_digest = @env["gallery.js"].hexdigest
    @env.version = 'v2'
    assert old_asset_digest == @env["gallery.js"].hexdigest
  end

  test "bundled asset is stale if its mtime is updated or deleted" do
    filename = File.join(fixture_path("default"), "tmp.js")

    sandbox filename do
      assert_nil @env["tmp.js"]

      File.open(filename, 'w') { |f| f.write "foo;\n" }
      assert_equal "foo;\n", @env["tmp.js"].to_s

      File.open(filename, 'w') { |f| f.write "bar;\n" }
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

      File.open(filename, 'wb') { |f| f.write "\x01\x02\x03" }
      assert_equal "\x01\x02\x03", @env["tmp.png"].to_s

      File.open(filename, 'wb') { |f| f.write "\x04\x05\x06" }
      time = Time.now + 60
      File.utime(time, time, filename)
      assert_equal "\x04\x05\x06", @env["tmp.png"].to_s

      File.unlink(filename)
      assert_nil @env["tmp.png"]
    end
  end

  test "bundled asset cached if theres an error building it" do
    @env.cache = nil

    filename = File.join(fixture_path("default"), "tmp.coffee")

    sandbox filename do
      File.open(filename, 'w') { |f| f.write "-->" }
      begin
        @env["tmp.js"].to_s
      rescue ExecJS::Error => e
        assert e
      else
        flunk "nothing raised"
      end

      File.open(filename, 'w') { |f| f.write "->" }
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

  test "disabling default directive preprocessor" do
    assert processor = @env.preprocessors['application/javascript'][0]
    assert_kind_of Sprockets::DirectiveProcessor, processor
    @env.unregister_preprocessor('application/javascript', processor)
    assert_equal "// =require \"notfound\"\n", @env["missing_require.js"].to_s
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
    assert_raises RuntimeError do
      @env.register_mime_type "application/javascript", ".jst"
    end
  end

  test "does not allow new bundle processors to be added" do
    assert_raises RuntimeError do
      @env.register_bundle_processor 'text/css', WhitespaceProcessor
    end
  end

  test "does not allow bundle processors to be removed" do
    assert_raises RuntimeError do
      @env.unregister_bundle_processor 'text/css', WhitespaceProcessor
    end
  end

  test "change in environment bundle_processors does not affect cache" do
    env = Sprockets::Environment.new(".")
    cached = env.cached

    assert !cached.bundle_processors['text/css'].include?(WhitespaceProcessor)
    env.register_bundle_processor 'text/css', WhitespaceProcessor
    assert !cached.bundle_processors['text/css'].include?(WhitespaceProcessor)
  end

  test "does not allow css compressor to be changed" do
    assert_raises RuntimeError do
      @env.css_compressor = WhitespaceCompressor
    end
  end

  test "does not allow js compressor to be changed" do
    assert_raises RuntimeError do
      @env.js_compressor = WhitespaceCompressor
    end
  end
end
