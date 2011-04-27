require 'sprockets_test'

class TestEnginePathname < Sprockets::TestCase
  test "identity initialization" do
    path = pathname("javascripts/application.js.coffee")
    assert pathname(path).equal?(path)
  end

  test "basename with extensions" do
    assert_equal "empty",
      pathname("empty").basename_without_extensions.to_s
    assert_equal "gallery",
      pathname("gallery.js").basename_without_extensions.to_s
    assert_equal "application",
      pathname("application.js.coffee").basename_without_extensions.to_s
    assert_equal "project",
      pathname("project.js.coffee.erb").basename_without_extensions.to_s
    assert_equal "gallery",
      pathname("gallery.css.erb").basename_without_extensions.to_s
  end

  test "extensions" do
    assert_equal [],
      pathname("empty").extensions
    assert_equal [".js"],
      pathname("gallery.js").extensions
    assert_equal [".js", ".coffee"],
      pathname("application.js.coffee").extensions
    assert_equal [".js", ".coffee", ".erb"],
      pathname("project.js.coffee.erb").extensions
    assert_equal [".css", ".erb"],
      pathname("gallery.css.erb").extensions
  end

  test "format_extension" do
    assert_equal nil, pathname("empty").format_extension
    assert_equal ".js", pathname("gallery.js").format_extension
    assert_equal ".js", pathname("application.js.coffee").format_extension
    assert_equal ".js", pathname("project.js.coffee.erb").format_extension
    assert_equal ".css", pathname("gallery.css.erb").format_extension
    assert_equal nil, pathname("gallery.erb").format_extension
    assert_equal nil, pathname("gallery.foo").format_extension
    assert_equal ".js", pathname("jquery.js").format_extension
    assert_equal ".js", pathname("jquery.min.js").format_extension
    assert_equal ".js", pathname("jquery.tmpl.js").format_extension
    assert_equal ".js", pathname("jquery.tmpl.min.js").format_extension
  end

  test "engine_extensions" do
    assert_equal [], pathname("empty").engine_extensions
    assert_equal [], pathname("gallery.js").engine_extensions
    assert_equal [".coffee"],
      pathname("application.js.coffee").engine_extensions
    assert_equal [".coffee", ".erb"],
      pathname("project.js.coffee.erb").engine_extensions
    assert_equal [".erb"], pathname("gallery.css.erb").engine_extensions
    assert_equal [".erb"], pathname("gallery.erb").engine_extensions
    assert_equal [], pathname("jquery.js").engine_extensions
    assert_equal [], pathname("jquery.min.js").engine_extensions
    assert_equal [], pathname("jquery.tmpl.min.js").engine_extensions
    assert_equal [".erb"], pathname("jquery.js.erb").engine_extensions
    assert_equal [".erb"], pathname("jquery.min.js.erb").engine_extensions
    assert_equal [".coffee"],
      pathname("jquery.min.coffee").engine_extensions
  end

  test "content_type" do
    assert_equal "application/octet-stream",
      pathname("empty").content_type
    assert_equal "application/javascript",
      pathname("gallery.js").content_type
    assert_equal "application/javascript",
      pathname("application.js.coffee").content_type
    assert_equal "application/javascript",
      pathname("project.js.coffee.erb").content_type
    assert_equal "text/css",
      pathname("gallery.css.erb").content_type
    assert_equal "application/javascript",
      pathname("jquery.tmpl.min.js").content_type

    if Tilt::CoffeeScriptTemplate.respond_to?(:default_mime_type)
      assert_equal "application/javascript",
        pathname("application.coffee").content_type
    end
  end

  private
    def pathname(path)
      Sprockets::EnginePathname.new(path, Sprockets::Engines.new)
    end
end
