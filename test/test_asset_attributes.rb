require 'sprockets_test'

class TestAssetAttributes < Sprockets::TestCase
  test "expand and relativize root" do
    assert_equal __FILE__,
      pathname(pathname(__FILE__).relativize_root).expand_root
  end

  test "search paths" do
    assert_equal ["index.js"],
      pathname("index.js").search_paths
    assert_equal ["foo.js", "foo/index.js"],
      pathname("foo.js").search_paths
    assert_equal ["foo/bar.js", "foo/bar/index.js"],
      pathname("foo/bar.js").search_paths
  end

  test "logical path" do
    assert_raise Sprockets::FileOutsidePaths do
      pathname(fixture_path("missing/application.js")).logical_path
    end

    assert_equal "application.js", pathname(fixture_path("default/application.js")).logical_path
    assert_equal "application.css", pathname(fixture_path("default/application.css")).logical_path
    assert_equal "jquery.foo.min.js", pathname(fixture_path("default/jquery.foo.min.js")).logical_path

    assert_equal "application.js", pathname(fixture_path("default/application.js.erb")).logical_path
    assert_equal "application.js", pathname(fixture_path("default/application.js.coffee")).logical_path
    assert_equal "application.css", pathname(fixture_path("default/application.css.scss")).logical_path

    assert_equal "application.js", pathname(fixture_path("default/application.coffee")).logical_path
    assert_equal "application.css", pathname(fixture_path("default/application.scss")).logical_path
    assert_equal "hello.js", pathname(fixture_path("default/hello.jst.ejs")).logical_path
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

  test "format extension" do
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
    assert_equal ".js", pathname("jquery.csv.js").format_extension
    assert_equal ".js", pathname("jquery.csv.min.js").format_extension

    env = Sprockets::Environment.new
    env.register_engine '.ms', Class.new
    assert_equal nil, env.attributes_for("foo.jst.ms").format_extension
  end

  test "engine extensions" do
    assert_equal [], pathname("empty").engine_extensions
    assert_equal [], pathname("gallery.js").engine_extensions
    assert_equal [".coffee"], pathname("application.js.coffee").engine_extensions
    assert_equal [".coffee", ".erb"], pathname("project.js.coffee.erb").engine_extensions
    assert_equal [".erb"], pathname("gallery.css.erb").engine_extensions
    assert_equal [".erb"], pathname("gallery.erb").engine_extensions
    assert_equal [], pathname("jquery.js").engine_extensions
    assert_equal [], pathname("jquery.min.js").engine_extensions
    assert_equal [], pathname("jquery.tmpl.min.js").engine_extensions
    assert_equal [".erb"], pathname("jquery.js.erb").engine_extensions
    assert_equal [".erb"], pathname("jquery.min.js.erb").engine_extensions
    assert_equal [".coffee"], pathname("jquery.min.coffee").engine_extensions
    assert_equal [".erb"], pathname("jquery.csv.min.js.erb").engine_extensions
    assert_equal [".coffee", ".erb"], pathname("jquery.csv.min.js.coffee.erb").engine_extensions

    env = Sprockets::Environment.new
    env.register_engine '.ms', Class.new
    assert_equal [".jst", ".ms"], env.attributes_for("foo.jst.ms").engine_extensions
  end

  test "content type" do
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

  test "get path fingerprint" do
    assert_equal nil, pathname("foo.js").path_fingerprint
    assert_equal "0aa2105d29558f3eb790d411d7d8fb66",
      pathname("foo-0aa2105d29558f3eb790d411d7d8fb66.js").path_fingerprint
    assert_equal "0aa2105d29558f3eb790d411d7d8fb66",
      pathname("foo.bar-0aa2105d29558f3eb790d411d7d8fb66.js").path_fingerprint
  end

  test "inject path fingerprint" do
    assert_equal "foo-0aa2105d29558f3eb790d411d7d8fb66.js",
      pathname("foo.js").path_with_fingerprint("0aa2105d29558f3eb790d411d7d8fb66")
    assert_equal "foo-0aa2105d29558f3eb790d411d7d8fb66.js",
      pathname("foo-37b51d194a7513e45b56f6524f2d51f2.js").path_with_fingerprint("0aa2105d29558f3eb790d411d7d8fb66")
    assert_equal "jquery-1.5.1-0aa2105d29558f3eb790d411d7d8fb66.js",
      pathname("jquery-1.5.1.js").path_with_fingerprint("0aa2105d29558f3eb790d411d7d8fb66")
  end

  private
    def pathname(path)
      env = Sprockets::Environment.new
      env.append_path fixture_path("default")
      env.attributes_for(path)
    end
end
