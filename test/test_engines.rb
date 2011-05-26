require 'sprockets_test'
require 'sprockets/engines'
require 'tilt'

class AlertTemplate < Tilt::Template
  def self.default_mime_type
    'application/javascript'
  end

  def prepare
  end

  def evaluate(scope, locals, &block)
    "alert(#{data.inspect});"
  end
end

class StringTemplate < Tilt::Template
  def prepare
  end

  def evaluate(scope, locals, &block)
    data.gsub(/#\{.*?\}/, "moo")
  end
end

class TestEngines < Sprockets::TestCase
  ORIGINAL_ENGINES = Sprockets.instance_variable_get(:@engines)

  def setup
    Sprockets.instance_variable_set(:@engines, ORIGINAL_ENGINES.dup)
  end

  def teardown
    Sprockets.instance_variable_set(:@engines, ORIGINAL_ENGINES)
  end

  test "registering a global engine" do
    Sprockets.register_engine ".alert", AlertTemplate
    assert_equal AlertTemplate, Sprockets.engines("alert")
    assert_equal AlertTemplate, Sprockets.engines(".alert")

    env = new_environment
    asset = env["hello.alert"]
    assert_equal 'alert("Hello world!\n");', asset.to_s
    assert_equal 'application/javascript', asset.content_type
  end

  test "overriding an engine globally" do
    env1 = new_environment
    assert_equal %(console.log("Moo, #{RUBY_VERSION}");\n), env1["moo.js"].to_s

    Sprockets.register_engine ".str", StringTemplate
    env2 = new_environment
    assert_equal %(console.log("Moo, moo");\n), env2["moo.js"].to_s
  end

  test "overriding an engine in an environment" do
    env1 = new_environment
    env2 = new_environment

    env1.register_engine ".str", StringTemplate
    assert_equal %(console.log("Moo, moo");\n), env1["moo.js"].to_s

    assert_equal %(console.log("Moo, #{RUBY_VERSION}");\n), env2["moo.js"].to_s
  end

  def new_environment
    Sprockets::Environment.new.tap do |env|
      env.append_path(fixture_path('engines'))
    end
  end
end
