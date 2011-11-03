require 'sprockets_test'
require 'tilt'
require 'yaml'

class TestContext < Sprockets::TestCase
  def setup
    @env = Sprockets::Environment.new(".")
    @env.append_path(fixture_path('context'))
  end

  test "context environment is indexed" do
    instances = @env["environment.js"].to_s.split("\n")
    assert_match "Sprockets::Index", instances[0]
    assert_equal instances[0], instances[1]
  end

  test "source file properties are exposed in context" do
    json = @env["properties.js"].to_s.chomp.chop
    assert_equal({
      'pathname'     => fixture_path("context/properties.js.erb"),
      '__FILE__'     => fixture_path("context/properties.js.erb"),
      'root_path'    => fixture_path("context"),
      'logical_path' => "properties",
      'content_type' => "application/javascript"
    }, YAML.load(json))
  end

  test "extend context" do
    @env.context_class.class_eval do
      def datauri(path)
        require 'base64'
        Base64.encode64(File.open(path, "rb") { |f| f.read })
      end
    end

    assert_equal ".pow {\n  background: url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAZoAAAEsCAMAAADNS4U5AAAAGXRFWHRTb2Z0\n",
      @env["helpers.css"].to_s.lines.to_a[0..1].join
    assert_equal 58240, @env["helpers.css"].length
  end
end

class TestCustomProcessor < Sprockets::TestCase
  def setup
    @env = Sprockets::Environment.new
    @env.append_path(fixture_path('context'))
  end

  class YamlProcessor < Tilt::Template
    def initialize_engine
      require 'yaml'
    end

    def prepare
      @manifest = YAML.load(data)
    end

    def evaluate(context, locals)
      @manifest['require'].each do |logical_path|
        context.require_asset(logical_path)
      end
      ""
    end
  end

  test "custom processor using Context#require" do
    @env.register_engine :yml, YamlProcessor

    assert_equal "var Foo = {};\n\nvar Bar = {};\n", @env['application.js'].to_s
  end

  class DataUriProcessor < Tilt::Template
    def initialize_engine
      require 'base64'
    end

    def prepare
    end

    def evaluate(context, locals)
      data.gsub(/url\(\"(.+?)\"\)/) do
        path = context.resolve($1)
        context.depend_on(path)
        data = Base64.encode64(File.open(path, "rb") { |f| f.read })
        "url(data:image/png;base64,#{data})"
      end
    end
  end

  test "custom processor using Context#resolve and Context#depend_on" do
    @env.register_engine :embed, DataUriProcessor

    assert_equal ".pow {\n  background: url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAZoAAAEsCAMAAADNS4U5AAAAGXRFWHRTb2Z0\n",
      @env["sprite.css"].to_s.lines.to_a[0..1].join
    assert_equal 58240, @env["sprite.css"].length
  end

  test "block custom processor" do
    require 'base64'

    @env.register_preprocessor 'text/css', :data_uris do |context, data|
      data.gsub(/url\(\"(.+?)\"\)/) do
        path = context.resolve($1)
        context.depend_on(path)
        data = Base64.encode64(File.open(path, "rb") { |f| f.read })
        "url(data:image/png;base64,#{data})"
      end
    end

    assert_equal ".pow {\n  background: url(data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAZoAAAEsCAMAAADNS4U5AAAAGXRFWHRTb2Z0\n",
      @env["sprite.css.embed"].to_s.lines.to_a[0..1].join
    assert_equal 58240, @env["sprite.css.embed"].length
  end

  test "resolve with content type" do
    assert_equal [fixture_path("context/foo.js"),
     fixture_path("context/foo.js"),
     fixture_path("context/foo.js"),
     "foo.js is 'application/javascript', not 'text/css';"
    ].join(",\n"), @env["resolve_content_type.js"].to_s.strip
  end
end
