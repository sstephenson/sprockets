require "sprockets_test"

module AssetTests
  def self.test(name, &block)
    define_method("test #{name.inspect}", &block)
  end

  test "pathname is a Pathname that exists" do
    assert_kind_of Pathname, @asset.pathname
    assert @asset.pathname.exist?
  end

  test "mtime" do
    assert @asset.mtime
  end

  test "digest is source digest" do
    assert_equal @env.digest.update(@asset.to_s).hexdigest, @asset.digest
  end

  test "length is source length" do
    assert_equal @asset.to_s.length, @asset.length
  end

  test "stale?" do
    assert !@asset.stale?(@env)
  end

  test "fresh?" do
    assert @asset.fresh?(@env)
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

  test "to_a body parts equals to_s" do
    source = ""
    @asset.to_a.each do |asset|
      source << asset.body
    end
    assert_equal @asset.to_s, source
  end

  test "write to file" do
    target = fixture_path('asset/tmp.js')
    begin
      @asset.write_to(target)
      assert File.exist?(target)
      assert_equal @asset.mtime, File.mtime(target)
    ensure
      FileUtils.rm(target) if File.exist?(target)
      assert !File.exist?(target)
    end
  end

  test "write to gzipped file" do
    target = fixture_path('asset/tmp.js.gz')
    begin
      @asset.write_to(target)
      assert File.exist?(target)
      assert_equal @asset.mtime, File.mtime(target)
    ensure
      FileUtils.rm(target) if File.exist?(target)
      assert !File.exist?(target)
    end
  end
end

module FreshnessTests
  def self.test(name, &block)
    define_method("test #{name.inspect}", &block)
  end

  test "asset is stale when its contents has changed" do
    filename = fixture_path('asset/test.js')

    sandbox filename do
      File.open(filename, 'w') { |f| f.write "a;" }
      asset = asset('test.js')

      assert asset.fresh?(@env)

      File.open(filename, 'w') { |f| f.write "b;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, filename)

      assert asset.stale?(@env)
    end
  end

  test "asset is stale if the file is removed" do
    filename = fixture_path('asset/test.js')

    sandbox filename do
      File.open(filename, 'w') { |f| f.write "a;" }
      asset = asset('test.js')

      assert asset.fresh?(@env)

      File.unlink(filename)

      assert asset.stale?(@env)
    end
  end

  test "asset is stale when one of its source files is modified" do
    main = fixture_path('asset/test-main.js')
    dep  = fixture_path('asset/test-dep.js')

    sandbox main, dep do
      File.open(main, 'w') { |f| f.write "//= require test-dep\n" }
      File.open(dep, 'w') { |f| f.write "a;" }
      asset = asset('test-main.js')

      assert asset.fresh?(@env)

      File.open(dep, 'w') { |f| f.write "b;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, dep)

      assert asset.stale?(@env)
    end
  end

  test "asset is stale when one of its dependencies is modified" do
    main = fixture_path('asset/test-main.js')
    dep  = fixture_path('asset/test-dep.js')

    sandbox main, dep do
      File.open(main, 'w') { |f| f.write "//= depend_on test-dep\n" }
      File.open(dep, 'w') { |f| f.write "a;" }
      asset = asset('test-main.js')

      assert asset.fresh?(@env)

      File.open(dep, 'w') { |f| f.write "b;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, dep)

      assert asset.stale?(@env)
    end
  end

  test "asset is stale when one of its asset dependencies is modified" do
    main = fixture_path('asset/test-main.js')
    dep  = fixture_path('asset/test-dep.js')

    sandbox main, dep do
      File.open(main, 'w') { |f| f.write "//= depend_on_asset test-dep\n" }
      File.open(dep, 'w') { |f| f.write "a;" }
      asset = asset('test-main.js')

      assert asset.fresh?(@env)

      File.open(dep, 'w') { |f| f.write "b;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, dep)

      assert asset.stale?(@env)
    end
  end

  test "asset is stale when one of its source files dependencies is modified" do
    a = fixture_path('asset/test-a.js')
    b = fixture_path('asset/test-b.js')
    c = fixture_path('asset/test-c.js')

    sandbox a, b, c do
      File.open(a, 'w') { |f| f.write "//= require test-b\n" }
      File.open(b, 'w') { |f| f.write "//= require test-c\n" }
      File.open(c, 'w') { |f| f.write "c;" }
      asset_a = asset('test-a.js')
      asset_b = asset('test-b.js')
      asset_c = asset('test-c.js')

      assert asset_a.fresh?(@env)
      assert asset_b.fresh?(@env)
      assert asset_c.fresh?(@env)

      File.open(c, 'w') { |f| f.write "x;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, c)

      assert asset_a.stale?(@env)
      assert asset_b.stale?(@env)
      assert asset_c.stale?(@env)
    end
  end

  test "asset is stale when one of its dependency dependencies is modified" do
    a = fixture_path('asset/test-a.js')
    b = fixture_path('asset/test-b.js')
    c = fixture_path('asset/test-c.js')

    sandbox a, b, c do
      File.open(a, 'w') { |f| f.write "//= require test-b\n" }
      File.open(b, 'w') { |f| f.write "//= depend_on test-c\n" }
      File.open(c, 'w') { |f| f.write "c;" }
      asset_a = asset('test-a.js')
      asset_b = asset('test-b.js')
      asset_c = asset('test-c.js')

      assert asset_a.fresh?(@env)
      assert asset_b.fresh?(@env)
      assert asset_c.fresh?(@env)

      File.open(c, 'w') { |f| f.write "x;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, c)

      assert asset_a.stale?(@env)
      assert asset_b.stale?(@env)
      assert asset_c.stale?(@env)
    end
  end

  test "asset is stale when one of its asset dependency dependencies is modified" do
    a = fixture_path('asset/test-a.js')
    b = fixture_path('asset/test-b.js')
    c = fixture_path('asset/test-c.js')

    sandbox a, b, c do
      File.open(a, 'w') { |f| f.write "//= depend_on_asset test-b\n" }
      File.open(b, 'w') { |f| f.write "//= depend_on_asset test-c\n" }
      File.open(c, 'w') { |f| f.write "c;" }
      asset_a = asset('test-a.js')
      asset_b = asset('test-b.js')
      asset_c = asset('test-c.js')

      assert asset_a.fresh?(@env)
      assert asset_b.fresh?(@env)
      assert asset_c.fresh?(@env)

      File.open(c, 'w') { |f| f.write "x;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, c)

      assert asset_a.stale?(@env)
      assert asset_b.stale?(@env)
      assert asset_c.stale?(@env)
    end
  end

  test "asset if stale if once of its source files is removed" do
    main = fixture_path('asset/test-main.js')
    dep  = fixture_path('asset/test-dep.js')

    sandbox main, dep do
      File.open(main, 'w') { |f| f.write "//= require test-dep\n" }
      File.open(dep, 'w') { |f| f.write "a;" }
      asset = asset('test-main.js')

      assert asset.fresh?(@env)

      File.unlink(dep)

      assert asset.stale?(@env)
    end
  end

  test "asset is stale if a file is added to its require directory" do
    asset = asset("tree/all_with_require_directory.js")
    assert asset.fresh?(@env)

    dirname  = File.join(fixture_path("asset"), "tree/all")
    filename = File.join(dirname, "z.js")

    sandbox filename do
      File.open(filename, 'w') { |f| f.write "z" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, dirname)

      assert asset.stale?(@env)
    end
  end

  test "asset is stale if a file is added to its require tree" do
    asset = asset("tree/all_with_require_tree.js")
    assert asset.fresh?(@env)

    dirname  = File.join(fixture_path("asset"), "tree/all/b/c")
    filename = File.join(dirname, "z.js")

    sandbox filename do
      File.open(filename, 'w') { |f| f.write "z" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, dirname)

      assert asset.stale?(@env)
    end
  end

  test "asset is stale if its declared dependency changes" do
    sprite = fixture_path('asset/sprite.css.erb')
    image  = fixture_path('asset/POW.png')

    sandbox sprite, image do
      asset = asset('sprite.css')

      assert asset.fresh?(@env)

      File.open(image, 'w') { |f| f.write "(change)" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, image)

      assert asset.stale?(@env)
    end
  end
end

class StaticAssetTest < Sprockets::TestCase
  def setup
    @env = Sprockets::Environment.new
    @env.append_path(fixture_path('asset'))
    @env.cache = {}

    @asset = @env['POW.png']
  end

  include AssetTests

  test "logical path can find itself" do
    assert_equal @asset, @env[@asset.logical_path]
  end

  test "class" do
    assert_kind_of Sprockets::StaticAsset, @asset
  end

  test "content type" do
    assert_equal "image/png", @asset.content_type
  end

  test "length" do
    assert_equal 42917, @asset.length
  end

  test "splat" do
    assert_equal [@asset], @asset.to_a
  end

  test "dependencies" do
    assert_equal [], @asset.dependencies
  end

  test "to path" do
    assert_equal fixture_path('asset/POW.png'), @asset.to_path
  end

  test "body is entire contents" do
    assert_equal @asset.to_s, @asset.body
  end

  test "asset is fresh if its mtime and contents are the same" do
    assert @asset.fresh?(@env)
  end

  test "asset is fresh if its mtime is changed but its contents is the same" do
    filename = fixture_path('asset/test-POW.png')

    sandbox filename do
      File.open(filename, 'w') { |f| f.write "a" }
      asset = @env['test-POW.png']

      assert asset.fresh?(@env)

      File.open(filename, 'w') { |f| f.write "a" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, filename)

      assert asset.fresh?(@env)
    end
  end

  test "asset is stale when its contents has changed" do
    filename = fixture_path('asset/POW.png')

    sandbox filename do
      File.open(filename, 'w') { |f| f.write "a" }
      asset = @env['POW.png']

      assert asset.fresh?(@env)

      File.open(filename, 'w') { |f| f.write "b" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, filename)

      assert asset.stale?(@env)
    end
  end

  test "asset is stale if the file is removed" do
    filename = fixture_path('asset/POW.png')

    sandbox filename do
      File.open(filename, 'w') { |f| f.write "a" }
      asset = @env['POW.png']

      assert asset.fresh?(@env)

      File.unlink(filename)

      assert asset.stale?(@env)
    end
  end

  test "serializing asset to and from hash" do
    expected = @asset
    hash     = {}
    @asset.encode_with(hash)
    actual   = Sprockets::Asset.from_hash(@env, hash)

    assert_kind_of Sprockets::StaticAsset, actual
    assert_equal expected.logical_path, actual.logical_path
    assert_equal expected.pathname, actual.pathname
    assert_equal expected.content_type, actual.content_type
    assert_equal expected.length, actual.length
    assert_equal expected.digest, actual.digest
    assert_equal expected.fresh?(@env), actual.fresh?(@env)

    assert_equal expected.dependencies, actual.dependencies
    assert_equal expected.to_a, actual.to_a
    assert_equal expected.body, actual.body
    assert_equal expected.to_s, actual.to_s

    assert actual.eql?(expected)
    assert expected.eql?(actual)
  end
end

class ProcessedAssetTest < Sprockets::TestCase
  include FreshnessTests

  def setup
    @env = Sprockets::Environment.new
    @env.append_path(fixture_path('asset'))
    @env.cache = {}

    @asset = @env.find_asset('application.js', :bundle => false)
    @bundle = false
  end

  include AssetTests

  test "logical path can find itself" do
    assert_equal @asset, @env.find_asset(@asset.logical_path, :bundle => false)
  end

  test "class" do
    assert_kind_of Sprockets::ProcessedAsset, @asset
  end

  test "content type" do
    assert_equal "application/javascript", @asset.content_type
  end

  test "length" do
    assert_equal 69, @asset.length
  end

  test "splat" do
    assert_equal [@asset], @asset.to_a
  end

  test "dependencies" do
    assert_equal [], @asset.dependencies
  end

  test "to_s" do
    assert_equal "\n\n\ndocument.on('dom:loaded', function() {\n  $('search').focus();\n});\n", @asset.to_s
  end

  test "each" do
    body = ""
    @asset.each { |part| body << part }
    assert_equal "\n\n\ndocument.on('dom:loaded', function() {\n  $('search').focus();\n});\n", body
  end

  test "to_a" do
    body = ""
    @asset.to_a.each do |asset|
      body << asset.body
    end
    assert_equal "\n\n\ndocument.on('dom:loaded', function() {\n  $('search').focus();\n});\n", body
  end

  test "asset is fresh if its mtime and contents are the same" do
    assert @asset.fresh?(@env)
  end

  test "serializing asset to and from hash" do
    expected = @asset
    hash     = {}
    @asset.encode_with(hash)
    actual   = Sprockets::Asset.from_hash(@env, hash)

    assert_kind_of Sprockets::ProcessedAsset, actual
    assert_equal expected.logical_path, actual.logical_path
    assert_equal expected.pathname, actual.pathname
    assert_equal expected.content_type, actual.content_type
    assert_equal expected.length, actual.length
    assert_equal expected.digest, actual.digest
    assert_equal expected.fresh?(@env), actual.fresh?(@env)

    assert_equal expected.dependencies, actual.dependencies
    assert_equal expected.to_a, actual.to_a
    assert_equal expected.body, actual.body
    assert_equal expected.to_s, actual.to_s

    assert actual.eql?(expected)
    assert expected.eql?(actual)
  end

  def asset(logical_path)
    @env.find_asset(logical_path, :bundle => @bundle)
  end

  def resolve(logical_path)
    @env.resolve(logical_path)
  end
end

class BundledAssetTest < Sprockets::TestCase
  include FreshnessTests

  def setup
    @env = Sprockets::Environment.new
    @env.append_path(fixture_path('asset'))
    @env.cache = {}

    @asset = @env['application.js']
    @bundle = true
  end

  include AssetTests

  test "logical path can find itself" do
    assert_equal @asset, @env[@asset.logical_path]
  end

  test "class" do
    assert_kind_of Sprockets::BundledAsset, @asset
  end

  test "content type" do
    assert_equal "application/javascript", @asset.content_type
  end

  test "length" do
    assert_equal 159, @asset.length
  end

  test "to_s" do
    assert_equal "var Project = {\n  find: function(id) {\n  }\n};\nvar Users = {\n  find: function(id) {\n  }\n};\n\n\n\ndocument.on('dom:loaded', function() {\n  $('search').focus();\n});\n", @asset.to_s
  end

  test "each" do
    body = ""
    @asset.each { |part| body << part }
    assert_equal "var Project = {\n  find: function(id) {\n  }\n};\nvar Users = {\n  find: function(id) {\n  }\n};\n\n\n\ndocument.on('dom:loaded', function() {\n  $('search').focus();\n});\n", body
  end

  test "requiring the same file multiple times has no effect" do
    assert_equal read("project.js")+"\n\n\n", asset("multiple.js").to_s
  end

  test "requiring a file of a different format raises an exception" do
    assert_raise Sprockets::ContentTypeMismatch do
      asset("mismatch.js")
    end
  end

  test "splatted asset includes itself" do
    assert_equal [resolve("project.js")], asset("project.js").to_a.map(&:pathname)
  end

  test "splatted assets are processed assets" do
    assert asset("project.js").to_a.all? { |a| a.is_a?(Sprockets::ProcessedAsset) }
  end

  test "asset doesn't include self as dependency" do
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
    assert_equal "\n\n\ndocument.on('dom:loaded', function() {\n  $('search').focus();\n});\n",
      asset("application.js").body
  end

  test "bundling joins files with blank line" do
    assert_equal "var Project = {\n  find: function(id) {\n  }\n};\nvar Users = {\n  find: function(id) {\n  }\n};\n\n\n\ndocument.on('dom:loaded', function() {\n  $('search').focus();\n});\n",
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
    assert_equal read("users.js") + "var jQuery;\n\n\n", asset("unknownexts.min.js").to_s
  end

  test "processing a source file in compat mode" do
    assert_equal read("project.js") + "\n" + read("users.js") + "\n\n\n\n",
      asset("compat.js").to_s
  end

  test "included dependencies are inserted after the header of the dependent file" do
    assert_equal "# My Application\n\n" + read("project.js") + "\n\nhello();\n",
      asset("included_header.js").to_s
  end

  test "requiring a file with a relative path" do
    assert_equal read("project.js") + "\n",
      asset("relative/require.js").to_s
  end

  test "including a file with a relative path" do
    assert_equal "// Included relatively\n\n" + read("project.js") + "\n\nhello();\n", asset("relative/include.js").to_s
  end

  test "can't require files outside the load path" do
    assert_raise Sprockets::FileNotFound do
      asset("relative/require_outside_path.js")
    end
  end

  test "can't require absolute files outside the load path" do
    assert_raise Sprockets::FileOutsidePaths do
      asset("absolute/require_outside_path.js").to_s
    end
  end

  test "require_directory requires all child files in alphabetical order" do
    assert_equal(
      "ok(\"b.js.erb\");\n",
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
      asset("tree/all_with_require_tree.js").to_s + "\n\n\n\n\n\n"
    )
  end

  test "require_tree without an argument defaults to the current directory" do
    assert_equal(
      "a();\nb();\n",
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

  test "require_tree with a nonexistent path raises an exception" do
    assert_raise(Sprockets::ArgumentError) do
      asset("tree/with_logical_path/require_tree_with_nonexistent_path.js").to_s
    end
  end

  test "require_tree with a nonexistent absolute path raises an exception" do
    assert_raise(Sprockets::ArgumentError) do
      asset("absolute/require_nonexistent_path.js").to_s
    end
  end

  test "require_tree respects order of child dependencies" do
    assert_equal(
      "var c;\nvar b;\nvar a;\n\n",
      asset("tree/require_tree_alpha.js").to_s
    )
  end

  test "require_self inserts the current file's body at the specified point" do
    assert_equal "/* b.css */\n\nb { display: none }\n/*\n\n\n\n\n\n */\n.one {}\n\n\nbody {}\n.two {}\n.project {}\n", asset("require_self.css").to_s
  end

  test "multiple require_self directives raises and error" do
    assert_raise(Sprockets::ArgumentError) do
      asset("require_self_twice.css")
    end
  end

  test "stub single dependency" do
    assert_equal "var jQuery.UI = {};\n\n\n", asset("stub/skip_jquery").to_s
  end

  test "stub dependency tree" do
    assert_equal "var Foo = {};\n\n\n\n", asset("stub/application").to_s
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

  test "unknown directives are ignored" do
    assert_equal "var Project = {\n  find: function(id) {\n  }\n};\n\n//\n// = Foo\n//\n// == Examples\n//\n// Foo.bar()\n// => \"baz\"\nvar Foo;\n",
      asset("documentation.js").to_s
  end

  test "__FILE__ is properly set in templates" do
    assert_equal %(var filename = "#{resolve("filename.js")}";\n),
      asset("filename.js").to_s
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
    assert_equal 8, asset("unicode.js").length
  end

  test "asset digest" do
    assert asset("project.js").digest
  end

  test "asset digest path" do
    assert_match(/project-\w+\.js/, asset("project.js").digest_path)
  end

  test "asset is fresh if its mtime and contents are the same" do
    assert asset("application.js").fresh?(@env)
  end

  test "legacy constants.yml" do
    assert_equal "var Prototype = { version: '2.0' };\n",
      asset("constants.js").to_s
  end

  test "multiple charset defintions are stripped from css bundle" do
    assert_equal "@charset \"UTF-8\";\n.foo {}\n\n.bar {}\n\n\n", asset("charset.css").to_s
  end

  test "appends missing semicolons" do
    assert_equal "var Bar\n;\n\n(function() {\n  var Foo\n})\n;\n",
      asset("semicolons.js").to_s
  end

  test "serializing asset to and from hash" do
    expected = @asset
    hash     = {}
    @asset.encode_with(hash)
    actual   = Sprockets::Asset.from_hash(@env, hash)

    assert_kind_of Sprockets::BundledAsset, actual
    assert_equal expected.logical_path, actual.logical_path
    assert_equal expected.pathname, actual.pathname
    assert_equal expected.body, actual.body
    assert_equal expected.to_s, actual.to_s
    assert_equal expected.content_type, actual.content_type
    assert_equal expected.length, actual.length
    assert_equal expected.digest, actual.digest
    assert_equal expected.fresh?(@env), actual.fresh?(@env)

    assert_equal expected.dependencies, actual.dependencies
    assert_equal expected.to_a, actual.to_a
    assert_equal expected.to_s, actual.to_s

    assert actual.eql?(expected)
    assert expected.eql?(actual)
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
    @env.find_asset(logical_path, :bundle => @bundle)
  end

  def resolve(logical_path)
    @env.resolve(logical_path)
  end

  def read(logical_path)
    File.read(resolve(logical_path))
  end
end
