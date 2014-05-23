require 'sprockets_test'
require 'sprockets/bundle'

class TestBundle < Sprockets::TestCase
  test "bundle single file" do
    environment = Sprockets::Environment.new
    environment.append_path fixture_path('asset')

    filename = fixture_path('asset/project.js.erb')
    assert File.exist?(filename)

    input = {
      environment: environment,
      filename: filename,
      content_type: 'application/javascript',
      metadata: {}
    }

    data = "var Project = {\n  find: function(id) {\n  }\n};\n"
    result = Sprockets::Bundle.call(input)
    assert_equal data, result[:data]
    assert_equal [filename], result[:dependency_paths].to_a.sort
  end

  test "bundle multiple files" do
    environment = Sprockets::Environment.new
    environment.append_path fixture_path('asset')

    filename = fixture_path('asset/application.js')
    assert File.exist?(filename)

    input = {
      environment: environment,
      filename: filename,
      content_type: 'application/javascript',
      metadata: {}
    }

    data = "var Project = {\n  find: function(id) {\n  }\n};\nvar Users = {\n  find: function(id) {\n  }\n};\n\n\n\ndocument.on('dom:loaded', function() {\n  $('search').focus();\n});\n"
    result = Sprockets::Bundle.call(input)
    assert_equal data, result[:data]
    assert_equal [
      fixture_path('asset/application.js'),
      fixture_path('asset/project.js.erb'),
      fixture_path('asset/users.js.erb')
    ], result[:dependency_paths].to_a.sort
  end
end
