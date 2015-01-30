require 'sprockets_test'
require 'sprockets/engines'

class TestEngines < Sprockets::TestCase
  AlertProcessor = proc { |input|
    "alert(#{input[:data].inspect});"
  }

  test "registering engine" do
    env = new_environment
    env.register_engine ".alert", AlertProcessor, mime_type: 'application/javascript'
    asset = env["hello.alert"]
    assert_equal 'alert("Hello world!\n");', asset.to_s
    assert_equal 'application/javascript', asset.content_type
  end

  def new_environment
    Sprockets::Environment.new.tap do |env|
      env.append_path(fixture_path('engines'))
    end
  end
end
