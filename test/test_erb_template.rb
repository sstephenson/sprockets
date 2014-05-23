require 'sprockets_test'
require 'sprockets/erb_template'

class TestERBTemplate < Sprockets::TestCase
  test "compile js erb template" do
    environment = Sprockets::Environment.new

    input = {
      environment: environment,
      filename: "foo.js.erb",
      content_type: 'application/javascript',
      data: "var data = <%= JSON.generate({foo: true}) %>;",
      metadata: {},
      cache: Sprockets::Cache.new
    }

    output = "var data = {\"foo\":true};"
    assert_equal output, Sprockets::ERBTemplate.call(input)[:data]
  end

  test "compile erb template with depend_on call" do
    environment = Sprockets::Environment.new(FIXTURE_ROOT)
    environment.append_path fixture_path('default')

    path = fixture_path('default/gallery.js')
    input = {
      environment: environment,
      filename: "foo.js.erb",
      content_type: 'application/javascript',
      data: "<%= depend_on('#{path}') %>\nvar data = 'DATA';",
      metadata: {},
      cache: Sprockets::Cache.new
    }

    output = "var data = 'DATA';"
    result = Sprockets::ERBTemplate.call(input)
    assert_equal output, result[:data]
    assert_equal path, result[:dependency_paths].first
  end

  test "pass custom erb helpers to template" do
    environment = Sprockets::Environment.new

    template = Sprockets::ERBTemplate.new do
      def foo
        :bar
      end
    end

    input = {
      environment: environment,
      filename: "foo.js.erb",
      content_type: 'application/javascript',
      data: "var foo = <%= foo %>;",
      metadata: {},
      cache: Sprockets::Cache.new
    }

    output = "var foo = bar;"
    assert_equal output, template.call(input)[:data]
  end
end
