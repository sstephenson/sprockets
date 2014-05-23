require "sprockets_test"

module AssetTests
  def self.test(name, &block)
    define_method("test_#{name.inspect}", &block)
  end

  test "pathname is a Pathname that exists" do
    assert_kind_of Pathname, @asset.pathname
    assert @asset.pathname.exist?
  end

  test "mtime" do
    assert @asset.mtime
  end

  test "digest is source digest" do
    assert_equal Digest::SHA1.hexdigest(@asset.to_s), @asset.digest
  end

  test "length is source length" do
    assert_equal @asset.to_s.length, @asset.length
  end

  test "bytesize is source bytesize" do
    assert_equal @asset.to_s.bytesize, @asset.bytesize
  end

  test "splat asset" do
    assert_kind_of Array, @asset.to_a
  end

  test "to_a body parts equals to_s" do
    source = ""
    @asset.to_a.each do |asset|
      source << asset.to_s
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
    define_method("test_#{name.inspect}", &block)
  end

  test "modify asset contents" do
    filename = fixture_path('asset/test.js')

    sandbox filename do
      write(filename, "a;")
      asset      = asset('test.js')
      old_digest = asset.digest
      old_mtime  = asset.mtime
      assert_equal "a;\n", asset.to_s

      write(filename, "b;")
      asset = asset('test.js')
      refute_equal old_digest, asset.digest
      refute_equal old_mtime, asset.mtime
      assert_equal "b;\n", asset.to_s
    end
  end

  test "remove asset" do
    filename = fixture_path('asset/test.js')

    sandbox filename do
      write(filename, "a;")
      asset = asset('test.js')

      File.unlink(filename)

      refute asset('test.js')
    end
  end

  test "modify asset's dependency file" do
    main = fixture_path('asset/test-main.js.erb')
    dep  = fixture_path('asset/test-dep.js')

    sandbox main, dep do
      write(main, "//= depend_on test-dep\n<%= File.read('#{dep}') %>")
      write(dep, "a;")
      asset      = asset('test-main.js')
      old_mtime  = asset.mtime
      old_digest = asset.digest
      assert_equal "a;", asset.to_s

      write(dep, "b;")
      asset = asset('test-main.js')
      refute_equal old_mtime, asset.mtime
      refute_equal old_digest, asset.digest
      assert_equal "b;", asset.to_s
    end
  end

  test "remove asset's dependency file" do
    main = fixture_path('asset/test-main.js')
    dep  = fixture_path('asset/test-dep.js')

    sandbox main, dep do
      write(main, "//= depend_on test-dep\n")
      write(dep, "a;")
      asset = asset('test-main.js')

      File.unlink(dep)

      assert_raises(Sprockets::FileNotFound) do
        asset('test-main.js')
      end
    end
  end

  def write(filename, contents)
    if File.exist?(filename)
      File.open(filename, 'w') do |f|
        f.write(contents)
      end
      mtime = File.stat(filename).mtime.to_i + 1
      File.utime(mtime, mtime, filename)
    else
      File.open(filename, 'w') do |f|
        f.write(contents)
      end
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

  test "content type" do
    assert_equal "image/png", @asset.content_type
  end

  test "length" do
    assert_equal 42917, @asset.length
  end

  test "bytesize" do
    assert_equal 42917, @asset.bytesize
  end

  test "splat" do
    assert_equal [@asset], @asset.to_a
  end

  test "asset is fresh if its mtime is changed but its contents is the same" do
    filename = fixture_path('asset/test-POW.png')

    sandbox filename do
      File.open(filename, 'w') { |f| f.write "a" }
      asset = @env['test-POW.png']
      assert asset
      old_mtime = asset.mtime
      old_digest = asset.digest

      File.open(filename, 'w') { |f| f.write "a" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, filename)

      assert_equal old_mtime, @env['test-POW.png'].mtime
      assert_equal old_digest, @env['test-POW.png'].digest
    end
  end

  test "asset is stale when its contents has changed" do
    filename = fixture_path('asset/POW.png')

    sandbox filename do
      File.open(filename, 'w') { |f| f.write "a" }
      asset = @env['POW.png']
      assert asset
      old_mtime = asset.mtime
      old_digest = asset.digest

      File.open(filename, 'w') { |f| f.write "b" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, filename)

      refute_equal old_mtime, @env['POW.png'].mtime
      refute_equal old_digest, @env['POW.png'].digest
    end
  end

  test "asset is fresh if the file is removed" do
    filename = fixture_path('asset/POW.png')

    sandbox filename do
      File.open(filename, 'w') { |f| f.write "a" }
      asset = @env['POW.png']
      assert asset

      File.unlink(filename)

      refute @env['POW.png']
    end
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

  test "content type" do
    assert_equal "application/javascript", @asset.content_type
  end

  test "length" do
    assert_equal 69, @asset.length
  end

  test "splat" do
    assert_equal [@asset], @asset.to_a
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
      body << asset.to_s
    end
    assert_equal "\n\n\ndocument.on('dom:loaded', function() {\n  $('search').focus();\n});\n", body
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

  test "asset is stale when one of its source files is modified" do
    main = fixture_path('asset/test-main.js')
    dep  = fixture_path('asset/test-dep.js')

    sandbox main, dep do
      File.open(main, 'w') { |f| f.write "//= require test-dep\n" }
      File.open(dep, 'w') { |f| f.write "a;" }
      asset = asset('test-main.js')
      old_digest = asset.digest

      File.open(dep, 'w') { |f| f.write "b;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, dep)

      refute_equal old_digest, asset('test-main.js').digest
    end
  end

  test "asset is stale when one of its asset dependencies is modified" do
    main = fixture_path('asset/test-main.js')
    dep  = fixture_path('asset/test-dep.js')

    sandbox main, dep do
      File.open(main, 'w') { |f| f.write "//= depend_on_asset test-dep\n" }
      File.open(dep, 'w') { |f| f.write "a;" }
      asset = asset('test-main.js')
      old_mtime = asset.mtime
      old_digest = asset.digest

      File.open(dep, 'w') { |f| f.write "b;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, dep)

      asset = asset('test-main.js')
      refute_equal old_mtime, asset.mtime
      assert_equal old_digest, asset.digest
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

      old_asset_a_digest = asset_a.digest
      old_asset_b_digest = asset_b.digest
      old_asset_c_digest = asset_c.digest

      File.open(c, 'w') { |f| f.write "x;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, c)

      refute_equal old_asset_a_digest, asset('test-a.js').digest
      refute_equal old_asset_b_digest, asset('test-b.js').digest
      refute_equal old_asset_c_digest, asset('test-c.js').digest
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

      old_asset_a_mtime = asset_a.mtime
      old_asset_b_mtime = asset_b.mtime
      old_asset_c_mtime = asset_c.mtime

      File.open(c, 'w') { |f| f.write "x;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, c)

      refute_equal old_asset_a_mtime, asset('test-a.js').mtime
      refute_equal old_asset_b_mtime, asset('test-b.js').mtime
      refute_equal old_asset_c_mtime, asset('test-c.js').mtime
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

      old_asset_a_mtime = asset_a.mtime
      old_asset_b_mtime = asset_b.mtime
      old_asset_c_mtime = asset_c.mtime

      File.open(c, 'w') { |f| f.write "x;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, c)

      refute_equal old_asset_a_mtime, asset('test-a.js').mtime
      refute_equal old_asset_b_mtime, asset('test-b.js').mtime
      refute_equal old_asset_c_mtime, asset('test-c.js').mtime
    end
  end

  test "asset is stale if a file is added to its require directory" do
    asset = asset("tree/all_with_require_directory.js")
    assert asset
    old_mtime = asset.mtime

    dirname  = File.join(fixture_path("asset"), "tree/all")
    filename = File.join(dirname, "z.js")

    sandbox filename do
      File.open(filename, 'w') { |f| f.write "z" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, dirname)

      refute_equal old_mtime, asset("tree/all_with_require_directory.js").mtime
    end
  end

  test "asset is stale if a file is added to its require tree" do
    asset = asset("tree/all_with_require_tree.js")
    assert asset
    old_mtime = asset.mtime

    dirname  = File.join(fixture_path("asset"), "tree/all/b/c")
    filename = File.join(dirname, "z.js")

    sandbox filename do
      File.open(filename, 'w') { |f| f.write "z" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, dirname)

      refute_equal old_mtime, asset("tree/all_with_require_tree.js").mtime
    end
  end

  test "asset is stale if its declared dependency changes" do
    sprite = fixture_path('asset/sprite.css.erb')
    image  = fixture_path('asset/POW.png')

    sandbox sprite, image do
      asset = asset('sprite.css')
      assert asset
      old_mtime = asset.mtime

      File.open(image, 'w') { |f| f.write "(change)" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, image)

      refute_equal old_mtime, asset('sprite.css').mtime
    end
  end

  test "asset if stale if once of its source files is removed" do
    main = fixture_path('asset/test-main.js')
    dep  = fixture_path('asset/test-dep.js')

    sandbox main, dep do
      File.open(main, 'w') { |f| f.write "//= require test-dep\n" }
      File.open(dep, 'w') { |f| f.write "a;" }
      assert asset('test-main.js')

      File.unlink(dep)

      assert_raises(Sprockets::FileNotFound) do
        asset('test-main.js')
      end
    end
  end

  test "mtime is based on required assets" do
    required_asset = fixture_path('asset/dependencies/b.js')

    sandbox required_asset do
      mtime = Time.now + 1
      File.utime mtime, mtime, required_asset
      assert_equal mtime.to_i, asset('required_assets.js').mtime.to_i
    end
  end

  test "mtime is based on dependency paths" do
    asset_dependency = fixture_path('asset/dependencies/b.js')

    sandbox asset_dependency do
      mtime = Time.now + 1
      File.utime mtime, mtime, asset_dependency
      assert_equal mtime.to_i, asset('dependency_paths.js').mtime.to_i
    end
  end

  test "requiring the same file multiple times has no effect" do
    assert_equal read("project.js")+"\n\n\n", asset("multiple.js").to_s
  end

  test "requiring a file of a different format raises an exception" do
    assert_raises Sprockets::FileNotFound do
      asset("mismatch.js")
    end
  end

  test "source paths" do
    assert_equal ["project-729a810640240adfd653c3d958890cfc4ec0ea84.js"],
      asset("project.js").source_paths
    assert_equal ["project-729a810640240adfd653c3d958890cfc4ec0ea84.js",
                  "users-08ae3439d6c8fe911445a2fb6e07ee1dc12ca599.js",
                  "application-b5df367abb741cac6526b05a726e9e8d7bd863d2.js"],
      asset("application.js").source_paths
  end

  test "splatted asset includes itself" do
    assert_equal [resolve("project.js")], asset("project.js").to_a.map(&:filename)
  end

  test "splatted asset with child dependencies" do
    assert_equal [resolve("project.js"), resolve("users.js"), resolve("application.js")],
      asset("application.js").to_a.map(&:filename)
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

  test "requiring a file with a relative path" do
    assert_equal read("project.js") + "\n",
      asset("relative/require.js").to_s
  end

  test "can't require files outside the load path" do
    assert_raises Sprockets::FileOutsidePaths do
      asset("relative/require_outside_path.js")
    end
  end

  test "can't require absolute files outside the load path" do
    assert_raises Sprockets::FileOutsidePaths do
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
    assert_raises(Sprockets::ArgumentError) do
      asset("tree/with_logical_path/require_tree_with_logical_path.js").to_s
    end
  end

  test "require_tree with a nonexistent path raises an exception" do
    assert_raises(Sprockets::ArgumentError) do
      asset("tree/with_logical_path/require_tree_with_nonexistent_path.js").to_s
    end
  end

  test "require_tree with a nonexistent absolute path raises an exception" do
    assert_raises(Sprockets::ArgumentError) do
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
    assert_equal "/* b.css */\n\nb { display: none }\n/*\n\n\n\n */\n\n\nbody {}\n.project {}\n", asset("require_self.css").to_s
  end

  test "multiple require_self directives raises and error" do
    assert_raises(Sprockets::ArgumentError) do
      asset("require_self_twice.css")
    end
  end

  test "stub single dependency" do
    assert_equal "var jQuery.UI = {};\n\n\n", asset("stub/skip_jquery").to_s
  end

  test "stub dependency tree" do
    assert_equal "var Foo = {};\n\n\n\n", asset("stub/application").to_s
  end

  test "resolves circular requires" do
    assert_equal "var A;\nvar C;\nvar B;\n",
      asset("circle/a.js").to_s
    assert_equal "var B;\nvar A;\nvar C;\n",
      asset("circle/b.js").to_s
    assert_equal "var C;\nvar B;\nvar A;\n",
      asset("circle/c.js").to_s
  end

  test "unknown directives are ignored" do
    assert_equal "var Project = {\n  find: function(id) {\n  }\n};\n\n//\n// = Foo\n//\n// == Examples\n//\n// Foo.bar()\n// => \"baz\"\nvar Foo;\n",
      asset("unknown_directives.js").to_s
  end

  test "__FILE__ is properly set in templates" do
    assert_equal %(var filename = "#{resolve("filename.js")}";\n),
      asset("filename.js").to_s
  end

  test "asset inherits the format extension and content type of the original file" do
    asset = asset("project.js")
    assert_equal "application/javascript", asset.content_type
  end

  test "asset falls back to engines default mime type" do
    asset = asset("default_mime_type.js")
    assert_equal "application/javascript", asset.content_type
  end

  test "asset is a rack response body" do
    body = ""
    asset("project.js").each { |part| body += part }
    assert_equal asset("project.js").to_s, body
  end

  test "asset length is source length with unicode characters" do
    assert_equal 8, asset("unicode.js").length
  end

  test "asset length is source bytesize with unicode characters" do
    assert_equal 8, asset("unicode.js").bytesize
  end

  test "asset digest" do
    assert asset("project.js").digest
  end

  test "asset digest path" do
    assert_match(/project-\w+\.js/, asset("project.js").digest_path)
  end

  test "multiple charset defintions are stripped from css bundle" do
    assert_equal "@charset \"UTF-8\";\n.foo {}\n\n.bar {}\n\n\n", asset("charset.css").to_s
  end

  test "appends missing semicolons" do
    assert_equal "var Bar\n;\n\n(function() {\n  var Foo\n})\n;\n",
      asset("semicolons.js").to_s
  end

  test "should not fail if home is not set in environment" do
    begin
      home, ENV["HOME"] = ENV["HOME"], nil
      env = Sprockets::Environment.new
      env.append_path(fixture_path('asset'))
      env['application.js']
    rescue Exception
      flunk
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

class AssetLogicalPathTest < Sprockets::TestCase
  def setup
    @env = Sprockets::Environment.new
    @env.append_path(fixture_path('paths'))
  end

  test "logical path" do
    assert_equal "empty", logical_path("empty")

    assert_equal "application.js", logical_path("application.js")
    assert_equal "application.css", logical_path("application.css")

    assert_equal "application.js", logical_path("application.js.erb")
    assert_equal "application.js", logical_path("application.js.coffee")
    assert_equal "application.css", logical_path("application.css.scss")
    assert_equal "project.js", logical_path("project.js.coffee.erb")

    assert_equal "store.css", logical_path("store.css.erb")
    assert_equal "store.foo", logical_path("store.foo")
    assert_equal "files", logical_path("files.erb")

    assert_equal "application.js", logical_path("application.coffee")
    assert_equal "application.css", logical_path("application.scss")
    assert_equal "hello.js", logical_path("hello.jst.ejs")

    assert_equal "bower/main.js", logical_path("bower/main.js")
    assert_equal "bower/bower.json", logical_path("bower/bower.json")

    assert_equal "coffee.js", logical_path("coffee/index.js")
    assert_equal "coffee/foo.js", logical_path("coffee/foo.coffee")

    assert_equal "jquery.js", logical_path("jquery.js")
    assert_equal "jquery.min.js", logical_path("jquery.min.js")
    assert_equal "jquery.csv.js", logical_path("jquery.csv.js")
    assert_equal "jquery.csv.min.js", logical_path("jquery.csv.min.js")
    assert_equal "jquery.foo.min.js", logical_path("jquery.foo.min.js")
    assert_equal "jquery.tmpl.js", logical_path("jquery.tmpl.js")
    assert_equal "jquery.tmpl.min.js", logical_path("jquery.tmpl.min.js")
    assert_equal "jquery.ext.js", logical_path("jquery.ext/index.js")
    assert_equal "jquery.ext/form.js", logical_path("jquery.ext/form.js")
    assert_equal "jquery-coffee.min.js", logical_path("jquery-coffee.min.coffee")
    assert_equal "jquery-custom.min.js", logical_path("jquery-custom.min.js.erb")
    assert_equal "jquery.js.min", logical_path("jquery.js.min")

    assert_equal "all.coffee/plain.js", logical_path("all.coffee/plain.js")
    assert_equal "all.coffee/hot.js", logical_path("all.coffee/hot.coffee")
    assert_equal "all.coffee.js", logical_path("all.coffee/index.coffee")

    assert_equal "sprite.css.embed", logical_path("sprite.css.embed")

    @env.register_engine '.haml', proc {}, mime_type: 'text/html'
    @env.register_engine '.ngt', proc {}, mime_type: 'application/javascript'
    assert_equal "foo.js", logical_path("foo.ngt.haml")
  end

  def logical_path(path)
    filename = fixture_path("paths/#{path}")
    assert File.exist?(filename), "#{filename} does not exist"
    silence_warnings do
      @env.find_asset(filename).logical_path
    end
  end
end

class AssetContentTypeTest < Sprockets::TestCase
  def setup
    @env = Sprockets::Environment.new
    @env.append_path(fixture_path('paths'))
  end

  test "content type" do
    assert_equal "application/octet-stream", content_type("empty")

    assert_equal "application/javascript", content_type("application.js")
    assert_equal "text/css", content_type("application.css")

    assert_equal "application/javascript", content_type("application.js.erb")
    assert_equal "application/javascript", content_type("application.js.coffee")
    assert_equal "text/css", content_type("application.css.scss")
    assert_equal "application/javascript", content_type("project.js.coffee.erb")

    assert_equal "text/css", content_type("store.css.erb")
    assert_equal "application/octet-stream", content_type("store.foo")
    assert_equal "application/octet-stream", content_type("files.erb")

    assert_equal "application/javascript", content_type("application.coffee")
    assert_equal "text/css", content_type("application.scss")
    assert_equal "application/javascript", content_type("hello.jst.ejs")

    assert_equal "application/javascript", content_type("bower/main.js")
    assert_equal "application/json", content_type("bower/bower.json")

    assert_equal "application/javascript", content_type("coffee/index.js")
    assert_equal "application/javascript", content_type("coffee/foo.coffee")

    assert_equal "application/javascript", content_type("jquery.js")
    assert_equal "application/javascript", content_type("jquery.min.js")
    assert_equal "application/javascript", content_type("jquery.csv.js")
    assert_equal "application/javascript", content_type("jquery.csv.min.js")
    assert_equal "application/javascript", content_type("jquery.foo.min.js")
    assert_equal "application/javascript", content_type("jquery.tmpl.js")
    assert_equal "application/javascript", content_type("jquery.tmpl.min.js")
    assert_equal "application/javascript", content_type("jquery.ext/index.js")
    assert_equal "application/javascript", content_type("jquery.ext/form.js")
    assert_equal "application/javascript", content_type("jquery-coffee.min.coffee")
    assert_equal "application/javascript", content_type("jquery-custom.min.js.erb")
    assert_equal "application/octet-stream", content_type("jquery.js.min")

    assert_equal "application/javascript", content_type("all.coffee/plain.js")
    assert_equal "application/javascript", content_type("all.coffee/hot.coffee")
    assert_equal "application/javascript", content_type("all.coffee/index.coffee")

    assert_equal "application/octet-stream", content_type("sprite.css.embed")

    @env.register_engine '.haml', proc {}, mime_type: 'text/html'
    @env.register_engine '.ngt', proc {}, mime_type: 'application/javascript'
    assert_equal "application/javascript", content_type("foo.ngt.haml")
  end

  def content_type(path)
    filename = fixture_path("paths/#{path}")
    assert File.exist?(filename), "#{filename} does not exist"
    silence_warnings do
      @env.find_asset(filename).content_type
    end
  end
end
