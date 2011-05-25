require "sprockets_test"

module AssetTests
  def self.test(name, &block)
    define_method("test #{name.inspect}", &block)
  end

  test "pathname is a Pathname that exists" do
    assert_kind_of Pathname, @asset.pathname
    assert @asset.pathname.exist?
  end

  test "logical path can find itself" do
    assert_equal @asset, @env[@asset.logical_path]
  end

  test "content type" do
    assert_equal "application/javascript", @asset.content_type
  end

  test "mtime" do
    assert @asset.mtime
  end

  test "length" do
    assert_equal 157, @asset.length
  end

  test "digest" do
    assert_equal "a64bb1a34523baef725ad44d492269e1", @asset.digest
  end

  test "each" do
    body = ""
    @asset.each { |part| body << part }
    assert_equal "var Project = {\n  find: function(id) {\n  }\n};\nvar Users = {\n  find: function(id) {\n  }\n};\n\ndocument.on('dom:loaded', function() {\n  $('search').focus();\n});\n", body
  end

  test "stale?" do
    assert !@asset.stale?
  end

  test "to_s" do
    assert_equal "var Project = {\n  find: function(id) {\n  }\n};\nvar Users = {\n  find: function(id) {\n  }\n};\n\ndocument.on('dom:loaded', function() {\n  $('search').focus();\n});\n", @asset.to_s
  end

  test "dependencies are an Array" do
    assert_kind_of Array, @asset.dependencies
  end

  test "splat asset" do
    assert_kind_of Array, @asset.to_a
  end

  test "body is a String" do
    assert_kind_of String, @asset.body
  end
end

class StaticAssetTest < Sprockets::TestCase
  def setup
    @env = Sprockets::Environment.new
    @env.static_root = fixture_path('public')

    @asset = @env['compiled-application.js']
  end

  include AssetTests

  test "class" do
    assert_kind_of Sprockets::StaticAsset, @asset
  end

  test "splat" do
    assert_equal [@asset], @asset.to_a
  end

  test "dependencies" do
    assert_equal [], @asset.dependencies
  end

  test "dependencies?" do
    assert !@asset.dependencies?
  end

  test "to path" do
    assert_equal fixture_path('public/compiled-application.js'), @asset.to_path
  end

  test "body is entire contents" do
    assert_equal @asset.to_s, @asset.body
  end
end

class BundledAssetTest < Sprockets::TestCase
  def setup
    @env = Sprockets::Environment.new
    @env.append_path(fixture_path('asset'))

    @asset = @env['application.js']
  end

  include AssetTests

  test "class" do
    assert_kind_of Sprockets::BundledAsset, @asset
  end

  test "requiring the same file multiple times has no effect" do
    assert_equal read("project.js")+"\n", asset("multiple.js").to_s
  end

  test "requiring a file of a different format raises an exception" do
    assert_raise Sprockets::ContentTypeMismatch do
      asset("mismatch.js")
    end
  end

  test "splatted asset includes itself" do
    assert_equal [resolve("project.js")], asset("project.js").to_a.map(&:pathname)
  end

  test "asset includes self as dependency" do
    assert_equal [], asset("project.js").dependencies.map(&:pathname)
  end

  test "asset with child dependencies" do
    assert_equal [resolve("project.js"), resolve("users.js")],
      asset("application.js").dependencies.map(&:pathname)
  end

  test "splatted asset with child dependencies" do
    assert_equal [resolve("project.js"), resolve("users.js"), resolve("application.js")],
      asset("application.js").to_a.map(&:pathname)
  end

  test "bundled asset body is just its own contents" do
    assert_equal "\ndocument.on('dom:loaded', function() {\n  $('search').focus();\n});\n",
      asset("application.js").body
  end

  test "bundling joins files with blank line" do
    assert_equal "var Project = {\n  find: function(id) {\n  }\n};\nvar Users = {\n  find: function(id) {\n  }\n};\n\ndocument.on('dom:loaded', function() {\n  $('search').focus();\n});\n",
      asset("application.js").to_s
  end

  test "dependencies appear in the source before files that required them" do
    assert_match(/Project.+Users.+focus/m, asset("application.js").to_s)
  end

  test "processing a source file with no engine extensions" do
    assert_equal read("users.js"), asset("noengine.js").to_s
  end

  test "processing a source file with one engine extension" do
    assert_equal read("users.js"), asset("oneengine.js").to_s
  end

  test "processing a source file with multiple engine extensions" do
    assert_equal read("users.js"),  asset("multipleengine.js").to_s
  end

  test "processing a source file with unknown extensions" do
    assert_equal read("users.js") + "jQuery\n", asset("unknownexts.min.js").to_s
  end

  test "processing a source file in compat mode" do
    assert_equal read("project.js") + "\n" + read("users.js"),
      asset("compat.js").to_s
  end

  test "included dependencies are inserted after the header of the dependent file" do
    assert_equal "# My Application\n" + read("project.js") + "\n\nhello()\n",
      asset("included_header.js").to_s
  end

  test "requiring a file with a relative path" do
    assert_equal read("project.js") + "\n",
      asset("relative/require.js").to_s
  end

  test "including a file with a relative path" do
    assert_equal "// Included relatively\n" + read("project.js") + "\n\nhello()\n", asset("relative/include.js").to_s
  end

  test "can't require files outside the load path" do
    assert_raise Sprockets::FileNotFound do
      asset("relative/require_outside_path.js")
    end
  end

  test "require_directory requires all child files in alphabetical order" do
    assert_equal(
      "ok(\"b.js.erb\")\n",
      asset("tree/all_with_require_directory.js").to_s
    )
  end

  test "require_directory current directory includes self last" do
    assert_equal(
      "var Bar;\nvar Foo;\nvar App;\n",
      asset("tree/directory/application.js").to_s
    )
  end

  test "require_tree requires all descendant files in alphabetical order" do
    assert_equal(
      asset("tree/all_with_require.js").to_s,
      asset("tree/all_with_require_tree.js").to_s
    )
  end

  test "require_tree without an argument defaults to the current directory" do
    assert_equal(
      "a()\n\nb()\n\n",
      asset("tree/without_argument/require_tree_without_argument.js").to_s
    )
  end

  test "require_tree with current directory includes self last" do
    assert_equal(
      "var Bar;\nvar Foo;\nvar App;\n",
      asset("tree/tree/application.js").to_s
    )
  end

  test "require_tree with a logical path argument raises an exception" do
    assert_raise(Sprockets::ArgumentError) do
      asset("tree/with_logical_path/require_tree_with_logical_path.js").to_s
    end
  end

  test "require_self inserts the current file's body at the specified point" do
    assert_equal "/* b.css */\n\nb { display: none }\n/*\n */\n.one {}\n\n\nbody {}\n.two {}\n.project {}\n", asset("require_self.css").to_s
  end

  test "multiple require_self directives raises and error" do
    assert_raise(Sprockets::ArgumentError) do
      asset("require_self_twice.css")
    end
  end

  test "circular require raises an error" do
    assert_raise(Sprockets::CircularDependencyError) do
      asset("circle/a.js")
    end
    assert_raise(Sprockets::CircularDependencyError) do
      asset("circle/b.js")
    end
    assert_raise(Sprockets::CircularDependencyError) do
      asset("circle/c.js")
    end
  end

  test "__FILE__ is properly set in templates" do
    assert_equal %(var filename = "#{resolve("filename.js")}";\n),
      asset("filename.js").to_s
  end

  test "asset mtime is the latest mtime of all processed sources" do
    mtime = Time.now
    path  = resolve("project.js")
    File.utime(mtime, mtime, path.to_s)
    assert_equal File.mtime(path), asset("application.js").mtime
  end

  test "asset inherits the format extension and content type of the original file" do
    asset = asset("project.js")
    assert_equal "application/javascript", asset.content_type
  end

  if Tilt::CoffeeScriptTemplate.respond_to?(:default_mime_type)
    test "asset falls back to engines default mime type" do
      asset = asset("default_mime_type.js")
      assert_equal "application/javascript", asset.content_type
    end
  end

  test "asset is a rack response body" do
    body = ""
    asset("project.js").each { |part| body += part }
    assert_equal asset("project.js").to_s, body
  end

  test "asset length is source length" do
    assert_equal 46, asset("project.js").length
  end

  test "asset length is source length with unicode characters" do
    assert_equal 4, asset("unicode.js").length
  end

  test "asset digest" do
    assert_equal "35d470ef8621efa573dee227a4feaba3", asset("project.js").digest
  end

  test "asset is stale when one of its source files is modified" do
    asset = asset("application.js")
    assert !asset.stale?

    mtime = Time.now + 1
    File.utime(mtime, mtime, resolve("project.js").to_s)

    assert asset.stale?
  end

  test "asset is stale if a file is added to its require directory" do
    asset = asset("tree/all_with_require_directory.js")
    assert !asset.stale?

    dirname  = File.join(fixture_path("asset"), "tree/all")
    filename = File.join(dirname, "z.js")

    begin
      File.open(filename, 'w') { |f| f.write "z" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, dirname)

      assert asset.stale?
    ensure
      File.unlink(filename) if File.exist?(filename)
      assert !File.exist?(filename)
    end
  end

  test "asset is stale if a file is added to its require tree" do
    asset = asset("tree/all_with_require_tree.js")
    assert !asset.stale?

    dirname  = File.join(fixture_path("asset"), "tree/all/b/c")
    filename = File.join(dirname, "z.js")

    begin
      File.open(filename, 'w') { |f| f.write "z" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, dirname)

      assert asset.stale?
    ensure
      File.unlink(filename) if File.exist?(filename)
      assert !File.exist?(filename)
    end
  end

  test "asset is stale if its declared dependency changes" do
    asset = asset("sprite.css")
    assert !asset.stale?

    mtime = Time.now + 1
    File.utime(mtime, mtime, resolve("POW.png").to_s)

    assert asset.stale?
  end

  test "legacy constants.yml" do
    assert_equal "var Prototype = { version: '2.0' };\n",
      asset("constants.js").to_s
  end

  test "multiple charset defintions are stripped from css bundle" do
    assert_equal "@charset \"UTF-8\";\n.foo {}\n\n.bar {}\n", asset("charset.css").to_s
  end

  test "should not fail if home is not set in environment" do
    begin
      home, ENV["HOME"] = ENV["HOME"], nil
      assert_nothing_raised do
        env = Sprockets::Environment.new
        env.append_path(fixture_path('asset'))
        env['application.js']
      end
    ensure
      ENV["HOME"] = home
    end
  end

  def asset(logical_path)
    @env.index[logical_path]
  end

  def resolve(logical_path)
    @env.resolve(logical_path)
  end

  def read(logical_path)
    File.read(resolve(logical_path))
  end
end
