require "sprockets_test"

module AssetTests
  def self.test(name, &block)
    define_method("test_#{name.inspect}", &block)
  end

  test "id is a SHA256 String" do
    assert_kind_of String, @asset.id
    assert_match(/^[0-9a-f]{64}$/, @asset.id)
  end

  test "uri can find itself" do
    # assert_kind_of URI, @asset.uri
    assert_equal @asset, @env.load(@asset.uri)
  end

  test "length is source length" do
    assert_equal @asset.to_s.length, @asset.length
  end

  test "bytesize is source bytesize" do
    assert_equal @asset.to_s.bytesize, @asset.bytesize
  end

  test "links are a Set" do
    assert_kind_of Set, @asset.links
  end

  test "write to file" do
    target = fixture_path('asset/tmp.js')
    begin
      @asset.write_to(target)
      assert File.exist?(target)
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
    ensure
      FileUtils.rm(target) if File.exist?(target)
      assert !File.exist?(target)
    end
  end

  def normalize_uri(uri)
    uri.sub(/id=\w+/, 'id=xxx')
  end

  def normalize_uris(uris)
    uris.to_a.map { |uri| normalize_uri(uri) }.sort
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
      old_digest = asset.hexdigest
      old_uri    = asset.uri
      assert_equal "a;\n", asset.to_s

      write(filename, "b;")
      asset = asset('test.js')
      refute_equal old_digest, asset.hexdigest
      refute_equal old_uri, asset.uri
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
      old_digest = asset.hexdigest
      old_uri    = asset.uri
      assert_equal "a;", asset.to_s

      write(dep, "b;")
      asset = asset('test-main.js')
      refute_equal old_digest, asset.hexdigest
      refute_equal old_uri, asset.uri
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
end

class TextStaticAssetTest < Sprockets::TestCase
  def setup
    @env = Sprockets::Environment.new
    @env.append_path(fixture_path('asset'))
    @env.cache = {}

    @asset = @env['log.txt']
  end

  include AssetTests

  test "uri" do
    assert_equal "file://#{fixture_path('asset/log.txt')}?type=text/plain&id=xxx",
      normalize_uri(@asset.uri)
  end

  test "logical path can find itself" do
    assert_equal @asset, @env[@asset.logical_path]
  end

  test "content type" do
    assert_equal "text/plain", @asset.content_type
  end

  test "charset is UTF-8" do
    assert_equal 'utf-8', @asset.charset
  end

  test "length" do
    assert_equal 6, @asset.length
  end

  test "bytesize" do
    assert_equal 6, @asset.bytesize
  end
end

class BinaryStaticAssetTest < Sprockets::TestCase
  def setup
    @env = Sprockets::Environment.new
    @env.append_path(fixture_path('asset'))
    @env.cache = {}

    @asset = @env['POW.png']
  end

  include AssetTests

  test "uri" do
    assert_equal "file://#{fixture_path('asset/POW.png')}?type=image/png&id=xxx",
      normalize_uri(@asset.uri)
  end

  test "logical path can find itself" do
    assert_equal @asset, @env[@asset.logical_path]
  end

  test "content type" do
    assert_equal "image/png", @asset.content_type
  end

  test "charset is nil" do
    assert_equal nil, @asset.charset
  end

  test "length" do
    assert_equal 42917, @asset.length
  end

  test "bytesize" do
    assert_equal 42917, @asset.bytesize
  end

  test "source digest" do
    assert_equal [29, 162, 229, 157, 247, 93, 51, 216, 183, 76, 61, 113, 254, 237, 230, 152, 242, 3, 241, 54, 81, 44, 186, 171, 32, 198, 138, 91, 222, 189, 88, 0], @asset.digest.bytes.to_a
  end

  test "source hexdigest" do
    assert_equal "1da2e59df75d33d8b74c3d71feede698f203f136512cbaab20c68a5bdebd5800", @asset.hexdigest
  end

  test "source base64digest" do
    assert_equal "HaLlnfddM9i3TD1x/u3mmPID8TZRLLqrIMaKW969WAA=", @asset.base64digest
  end

  test "integrity" do
    assert_equal "ni:///sha-256;HaLlnfddM9i3TD1x_u3mmPID8TZRLLqrIMaKW969WAA?ct=image/png", @asset.integrity
  end

  test "asset is fresh if its mtime is changed but its contents is the same" do
    filename = fixture_path('asset/test-POW.png')

    sandbox filename do
      File.open(filename, 'w') { |f| f.write "a" }
      asset = @env['test-POW.png']
      assert asset
      old_digest = asset.hexdigest
      old_uri    = asset.uri

      File.open(filename, 'w') { |f| f.write "a" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, filename)

      assert_equal old_digest, @env['test-POW.png'].hexdigest
      assert_equal old_uri, @env['test-POW.png'].uri
    end
  end

  test "asset is stale when its contents has changed" do
    filename = fixture_path('asset/POW.png')

    sandbox filename do
      File.open(filename, 'w') { |f| f.write "a" }
      asset = @env['POW.png']
      assert asset
      old_digest = asset.hexdigest
      old_uri    = asset.uri

      File.open(filename, 'w') { |f| f.write "b" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, filename)

      refute_equal old_digest, @env['POW.png'].hexdigest
      refute_equal old_uri, @env['POW.png'].uri
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

  test "uri" do
    assert_equal "file://#{fixture_path('asset/application.js')}?type=application/javascript&skip_bundle&id=xxx",
      normalize_uri(@asset.uri)
  end

  test "logical path can find itself" do
    assert_equal @asset, @env.find_asset(@asset.logical_path, :bundle => false)
  end

  test "content type" do
    assert_equal "application/javascript", @asset.content_type
  end

  test "length" do
    assert_equal 69, @asset.length
  end

  test "source digest" do
    assert_equal [106, 95, 255, 137, 232, 50, 143, 21, 142, 119, 100, 43, 83, 227, 37, 194, 78, 216, 68, 166, 188, 213, 169, 110, 192, 249, 0, 67, 132, 233, 201, 165], @asset.digest.bytes.to_a
  end

  test "source hexdigest" do
    assert_equal "6a5fff89e8328f158e77642b53e325c24ed844a6bcd5a96ec0f9004384e9c9a5", @asset.hexdigest
  end

  test "source base64digest" do
    assert_equal "al//iegyjxWOd2QrU+Mlwk7YRKa81aluwPkAQ4TpyaU=", @asset.base64digest
  end

  test "integrity" do
    assert_equal "ni:///sha-256;al__iegyjxWOd2QrU-Mlwk7YRKa81aluwPkAQ4TpyaU?ct=application/javascript", @asset.integrity
  end

  test "charset is UTF-8" do
    assert_equal 'utf-8', @asset.charset
  end

  test "to_s" do
    assert_equal "\n\n\ndocument.on('dom:loaded', function() {\n  $('search').focus();\n});\n", @asset.to_s
  end

  test "each" do
    body = ""
    @asset.each { |part| body << part }
    assert_equal "\n\n\ndocument.on('dom:loaded', function() {\n  $('search').focus();\n});\n", body
  end

  def asset(logical_path, options = {})
    @env.find_asset(logical_path, {:bundle => @bundle}.merge(options))
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

  test "uri" do
    assert_equal "file://#{fixture_path('asset/application.js')}?type=application/javascript&id=xxx",
      normalize_uri(@asset.uri)
  end

  test "logical path can find itself" do
    assert_equal @asset, @env[@asset.logical_path]
  end

  test "content type" do
    assert_equal "application/javascript", @asset.content_type
  end

  test "length" do
    assert_equal 159, @asset.length
  end

  test "source digest" do
    assert_equal [149, 91, 45, 221, 208, 209, 68, 155, 28, 97, 113, 36, 184, 59, 70, 48, 14, 218, 222, 192, 109, 86, 17, 4, 247, 246, 22, 82, 65, 179, 26, 148], @asset.digest.bytes.to_a
  end

  test "source hexdigest" do
    assert_equal "955b2dddd0d1449b1c617124b83b46300edadec06d561104f7f6165241b31a94", @asset.hexdigest
  end

  test "source base64digest" do
    assert_equal "lVst3dDRRJscYXEkuDtGMA7a3sBtVhEE9/YWUkGzGpQ=", @asset.base64digest
  end

  test "integrity" do
    assert_equal "ni:///sha-256;lVst3dDRRJscYXEkuDtGMA7a3sBtVhEE9_YWUkGzGpQ?ct=application/javascript", @asset.integrity
  end

  test "charset is UTF-8" do
    assert_equal 'utf-8', @asset.charset
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
      old_digest = asset.hexdigest
      old_uri    = asset.uri

      File.open(dep, 'w') { |f| f.write "b;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, dep)

      refute_equal old_digest, asset('test-main.js').hexdigest
      refute_equal old_uri, asset('test-main.js').uri
    end
  end

  test "asset is stale when one of its asset dependencies is modified" do
    main = fixture_path('asset/test-main.js')
    dep  = fixture_path('asset/test-dep.js')

    sandbox main, dep do
      File.open(main, 'w') { |f| f.write "//= depend_on_asset test-dep\n" }
      File.open(dep, 'w') { |f| f.write "a;" }
      asset = asset('test-main.js')
      old_digest = asset.hexdigest
      old_uri    = asset.uri

      File.open(dep, 'w') { |f| f.write "b;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, dep)

      asset = asset('test-main.js')
      assert_equal old_digest, asset.hexdigest
      refute_equal old_uri, asset.uri
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

      old_asset_a_digest = asset_a.hexdigest
      old_asset_b_digest = asset_b.hexdigest
      old_asset_c_digest = asset_c.hexdigest
      old_asset_a_uri = asset_a.uri
      old_asset_b_uri = asset_b.uri
      old_asset_c_uri = asset_c.uri

      File.open(c, 'w') { |f| f.write "x;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, c)

      refute_equal old_asset_a_digest, asset('test-a.js').hexdigest
      refute_equal old_asset_b_digest, asset('test-b.js').hexdigest
      refute_equal old_asset_c_digest, asset('test-c.js').hexdigest
      refute_equal old_asset_a_uri, asset('test-a.js').uri
      refute_equal old_asset_b_uri, asset('test-b.js').uri
      refute_equal old_asset_c_uri, asset('test-c.js').uri
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

      old_asset_a_uri   = asset_a.uri
      old_asset_b_uri   = asset_b.uri
      old_asset_c_uri   = asset_c.uri

      File.open(c, 'w') { |f| f.write "x;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, c)

      refute_equal old_asset_a_uri, asset('test-a.js').uri
      refute_equal old_asset_b_uri, asset('test-b.js').uri
      refute_equal old_asset_c_uri, asset('test-c.js').uri
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

      old_asset_a_uri = asset_a.uri
      old_asset_b_uri = asset_b.uri
      old_asset_c_uri = asset_c.uri

      File.open(c, 'w') { |f| f.write "x;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, c)

      refute_equal old_asset_a_uri, asset('test-a.js').uri
      refute_equal old_asset_b_uri, asset('test-b.js').uri
      refute_equal old_asset_c_uri, asset('test-c.js').uri
    end
  end

  test "asset is stale when one of its linked assets is modified" do
    a = fixture_path('asset/test-a.js')
    b = fixture_path('asset/test-b.js')

    sandbox a, b do
      File.open(a, 'w') { |f| f.write "//= link test-b\n" }
      File.open(b, 'w') { |f| f.write "b;" }
      asset_a = asset('test-a.js')
      asset_b = asset('test-b.js')

      old_asset_a_uri = asset_a.uri
      old_asset_b_uri = asset_b.uri

      File.open(b, 'w') { |f| f.write "x;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, b)

      refute_equal old_asset_a_uri, asset('test-a.js').uri
      refute_equal old_asset_b_uri, asset('test-b.js').uri
    end
  end

  test "erb asset is stale when one of its linked assets is modified" do
    a = fixture_path('asset/test-a.js.erb')
    b = fixture_path('asset/test-b.js.erb')

    sandbox a, b do
      File.open(a, 'w') { |f| f.write "<% link_asset 'test-b' %>\n" }
      File.open(b, 'w') { |f| f.write "b;" }
      asset_a = asset('test-a.js')
      asset_b = asset('test-b.js')

      old_asset_a_uri = asset_a.uri
      old_asset_b_uri = asset_b.uri

      File.open(b, 'w') { |f| f.write "x;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, b)

      refute_equal old_asset_a_uri, asset('test-a.js').uri
      refute_equal old_asset_b_uri, asset('test-b.js').uri
    end
  end

  test "asset is stale if a file is added to its require directory" do
    asset = asset("tree/all_with_require_directory.js")
    assert asset
    old_uri = asset.uri

    dirname  = File.join(fixture_path("asset"), "tree/all")
    filename = File.join(dirname, "z.js")

    sandbox filename do
      File.open(filename, 'w') { |f| f.write "z" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, dirname)

      refute_equal old_uri, asset("tree/all_with_require_directory.js").uri
    end
  end

  test "asset is stale if a file is added to its require tree" do
    asset = asset("tree/all_with_require_tree.js")
    assert asset
    old_uri = asset.uri

    dirname  = File.join(fixture_path("asset"), "tree/all/b/c")
    filename = File.join(dirname, "z.js")

    sandbox filename do
      File.open(filename, 'w') { |f| f.write "z" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, dirname)

      refute_equal old_uri, asset("tree/all_with_require_tree.js").uri
    end
  end

  test "asset is stale if its declared dependency changes" do
    sprite = fixture_path('asset/sprite.css.erb')
    image  = fixture_path('asset/POW.png')

    sandbox sprite, image do
      asset = asset('sprite.css')
      assert asset
      old_uri = asset.uri

      File.open(image, 'w') { |f| f.write "(change)" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, image)

      refute_equal old_uri, asset('sprite.css').uri
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

  test "asset is stale when one of its stubbed targets dependencies are modified" do
    frameworks = fixture_path('asset/stub-frameworks.js')
    app        = fixture_path('asset/stub-app.js')
    jquery     = fixture_path('asset/stub-jquery.js')

    sandbox frameworks, app, jquery do
      write(frameworks, "frameworks = {};")
      write(app, "//= stub stub-frameworks\n//= require stub-jquery\napp = {};")
      write(jquery, "jquery = {};")

      asset_jquery = asset('stub-jquery.js', :bundle => false)

      refute asset('stub-frameworks.js').included.include?(asset_jquery.uri)
      assert asset('stub-app.js').included.include?(asset_jquery.uri)

      old_asset_frameworks_uri = asset('stub-frameworks.js').uri
      old_asset_app_uri        = asset('stub-app.js').uri

      write(frameworks, "//= require stub-jquery\nframeworks = {};")

      # jquery never changed
      assert_equal asset_jquery.uri, asset('stub-jquery.js', :bundle => false).uri

      # jquery moved from app to frameworks
      assert asset('stub-frameworks.js').included.include?(asset_jquery.uri)
      refute asset('stub-app.js').included.include?(asset_jquery.uri)

      refute_equal old_asset_frameworks_uri, asset('stub-frameworks.js').uri
      refute_equal old_asset_app_uri, asset('stub-app.js').uri
    end
  end

  test "requiring the same file multiple times has no effect" do
    assert_equal read("asset/project.js.erb")+"\n\n\n", asset("multiple.js").to_s
  end

  test "requiring a file of a different format raises an exception" do
    assert_raises Sprockets::FileNotFound do
      asset("mismatch.js")
    end
  end

  test "bundling joins files with blank line" do
    assert_equal "var Project = {\n  find: function(id) {\n  }\n};\nvar Users = {\n  find: function(id) {\n  }\n};\n\n\n\ndocument.on('dom:loaded', function() {\n  $('search').focus();\n});\n",
      asset("application.js").to_s
  end

  test "dependencies appear in the source before files that required them" do
    assert_match(/Project.+Users.+focus/m, asset("application.js").to_s)
  end

  test "processing a source file with no engine extensions" do
    assert_equal read("asset/users.js.erb"), asset("noengine.js").to_s
  end

  test "processing a source file with one engine extension" do
    assert_equal read("asset/users.js.erb"), asset("oneengine.js").to_s
  end

  test "processing a source file with multiple engine extensions" do
    assert_equal read("asset/users.js.erb"),  asset("multipleengine.js").to_s
  end

  test "processing a source file with unknown extensions" do
    assert_equal read("asset/users.js.erb") + "var jQuery;\n\n\n", asset("unknownexts.min.js").to_s
  end

  test "requiring a file with a relative path" do
    assert_equal read("asset/project.js.erb") + "\n",
      asset("relative/require.js").to_s
  end

  test "can't require files outside the load path" do
    assert !@env.paths.include?(fixture_path("default")), @env.paths.inspect

    assert_raises Sprockets::FileNotFound do
      asset("relative/require_outside_path.js")
    end
  end

  test "can't require files in another load path" do
    @env.append_path(fixture_path("default"))
    assert @env.paths.include?(fixture_path("default")), @env.paths.inspect

    assert_raises Sprockets::FileNotFound do
      asset("relative/require_other_load_path.js")
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

  test "linked asset depends on target asset" do
    assert asset = asset("require_manifest.js")
    assert_equal <<-EOS, asset.to_s

define("application.js", "application-955b2dddd0d1449b1c617124b83b46300edadec06d561104f7f6165241b31a94.js")
define("application.css", "application-46d50149c56fc370805f53c29f79b89a52d4cc479eeebcdc8db84ab116d7ab1a.css")
define("POW.png", "POW-1da2e59df75d33d8b74c3d71feede698f203f136512cbaab20c68a5bdebd5800.png")
    EOS
    assert_equal [
      "file://#{fixture_path("asset/POW.png")}?type=image/png&id=xxx",
      "file://#{fixture_path("asset/application.css")}?type=text/css&id=xxx",
      "file://#{fixture_path("asset/application.js")}?type=application/javascript&id=xxx"
    ], normalize_uris(asset.links)
  end

  test "directive linked asset depends on target asset" do
    assert asset = asset("require_manifest2.js")
    assert_equal <<-EOS, asset.to_s




define("application.js", "application-955b2dddd0d1449b1c617124b83b46300edadec06d561104f7f6165241b31a94.js")
define("application.css", "application-46d50149c56fc370805f53c29f79b89a52d4cc479eeebcdc8db84ab116d7ab1a.css")
define("POW.png", "POW-1da2e59df75d33d8b74c3d71feede698f203f136512cbaab20c68a5bdebd5800.png")
    EOS

    assert_equal [
      "file://#{fixture_path("asset/POW.png")}?type=image/png&id=xxx",
      "file://#{fixture_path("asset/application.css")}?type=text/css&id=xxx",
      "file://#{fixture_path("asset/application.js")}?type=application/javascript&id=xxx"
    ], normalize_uris(asset.links)
  end

  test "link_directory current directory includes self last" do
    assert_equal [
      "file://#{fixture_path("asset/link/directory/bar.js")}?type=application/javascript&id=xxx",
      "file://#{fixture_path("asset/link/directory/foo.js")}?type=application/javascript&id=xxx"
    ], normalize_uris(asset("link/directory/application.js").links)
  end

  test "link_tree requires all descendant files in alphabetical order" do
    assert_equal normalize_uris(asset("link/all_with_require.js").links),
      normalize_uris(asset("link/all_with_require_tree.js").links)
  end

  test "link_tree without an argument defaults to the current directory" do
    assert_equal [
      "file://#{fixture_path("asset/link/without_argument/a.js")}?type=application/javascript&id=xxx",
      "file://#{fixture_path("asset/link/without_argument/b.js")}?type=application/javascript&id=xxx"
    ], normalize_uris(asset("link/without_argument/require_tree_without_argument.js").links)
  end

  test "link_tree with current directory includes self last" do
    assert_equal [
      "file://#{fixture_path("asset/link/tree/bar.js")}?type=application/javascript&id=xxx",
      "file://#{fixture_path("asset/link/tree/foo.js")}?type=application/javascript&id=xxx"
    ], normalize_uris(asset("link/tree/application.js").links)
  end

  test "link_tree with a logical path argument raises an exception" do
    assert_raises(Sprockets::ArgumentError) do
      asset("link/with_logical_path/require_tree_with_logical_path.js")
    end
  end

  test "link_tree with a nonexistent path raises an exception" do
    assert_raises(Sprockets::ArgumentError) do
      asset("link/with_logical_path/require_tree_with_nonexistent_path.js")
    end
  end

  test "link_directory requires all child files in alphabetical order" do
    assert_equal [
      "file://#{fixture_path("asset/link/all/README.md")}?id=xxx",
      "file://#{fixture_path("asset/link/all/b.css")}?type=text/css&id=xxx",
      "file://#{fixture_path("asset/link/all/b.js.erb")}?type=application/javascript&id=xxx"
    ], normalize_uris(asset("link/all_with_require_directory.js").links)
  end

  test "link_tree respects order of child dependencies" do
    assert_equal [
      "file://#{fixture_path("asset/link/alpha/a.js")}?type=application/javascript&id=xxx",
      "file://#{fixture_path("asset/link/alpha/b.js")}?type=application/javascript&id=xxx",
      "file://#{fixture_path("asset/link/alpha/c.js")}?type=application/javascript&id=xxx"
    ], normalize_uris(asset("link/require_tree_alpha.js").links)
  end

  test "link_asset with uri" do
    assert asset = asset("link/asset_uri.css")
    assert_equal <<-EOS, asset.to_s
.logo {
  background: url(POW-1da2e59df75d33d8b74c3d71feede698f203f136512cbaab20c68a5bdebd5800.png);
}
    EOS
    assert_equal [
      "file://#{fixture_path("asset/POW.png")}?type=image/png&id=xxx"
      ], normalize_uris(asset.links)
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
    assert_equal %(var filename = "#{fixture_path("asset/filename.js.erb")}";\n),
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
    assert asset("project.js").hexdigest
  end

  test "asset digest path" do
    assert_match(/project-\w+\.js/, asset("project.js").digest_path)
  end

  test "multiple charset defintions are stripped from css bundle" do
    assert_equal "\n.foo {}\n\n.bar {}\n\n\n", asset("charset.css").to_s
  end

  test "appends missing semicolons" do
    assert_equal "var Bar\n;\n\n(function() {\n  var Foo\n})\n",
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

  def asset(logical_path, options = {})
    @env.find_asset(logical_path, {:bundle => @bundle}.merge(options))
  end

  def read(logical_path)
    File.read(fixture_path(logical_path))
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
    assert_equal "application.js", logical_path("application.coffee", accept: "application/javascript")
    assert_equal "application.css", logical_path("application.scss", accept: "text/css")
    assert_equal "project.js", logical_path("project.coffee.erb", accept: "application/javascript")

    assert_equal "store.css", logical_path("store.css.erb")
    assert_equal "store.foo", logical_path("store.foo")
    assert_equal "files.txt", logical_path("files.erb")

    assert_equal "application.js", logical_path("application.coffee", accept: "application/javascript")
    assert_equal "application.css", logical_path("application.scss", accept: "text/css")
    assert_equal "hello.js", logical_path("hello.jst.ejs")

    assert_equal "bower/main.js", logical_path("bower/main.js")
    assert_equal "bower/bower.json", logical_path("bower/bower.json")

    assert_equal "coffee.js", logical_path("coffee/index.js")
    assert_equal "coffee/foo.js", logical_path("coffee/foo.coffee", accept: "application/javascript")

    assert_equal "jquery.js", logical_path("jquery.js")
    assert_equal "jquery.min.js", logical_path("jquery.min.js")
    assert_equal "jquery.csv.js", logical_path("jquery.csv.js")
    assert_equal "jquery.csv.min.js", logical_path("jquery.csv.min.js")
    assert_equal "jquery.foo.min.js", logical_path("jquery.foo.min.js")
    assert_equal "jquery.tmpl.js", logical_path("jquery.tmpl.js")
    assert_equal "jquery.tmpl.min.js", logical_path("jquery.tmpl.min.js")
    assert_equal "jquery.ext.js", logical_path("jquery.ext/index.js")
    assert_equal "jquery.ext/form.js", logical_path("jquery.ext/form.js")
    assert_equal "jquery-coffee.min.js", logical_path("jquery-coffee.min.coffee", accept: "application/javascript")
    assert_equal "jquery-custom.min.js", logical_path("jquery-custom.min.js.erb")
    assert_equal "jquery.js.min", logical_path("jquery.js.min")

    assert_equal "all.coffee/plain.js", logical_path("all.coffee/plain.js")
    assert_equal "all.coffee/hot.js", logical_path("all.coffee/hot.coffee", accept: "application/javascript")
    assert_equal "all.coffee.js", logical_path("all.coffee/index.coffee", accept: "application/javascript")

    assert_equal "foo-ng.js", logical_path("foo-ng.ngt")
    assert_equal "bar-ng.js", logical_path("bar-ng.ngt.haml")
    assert_equal "baz-ng.js", logical_path("baz-ng.js.ngt")

    assert_equal "sprite.css.embed", logical_path("sprite.css.embed")
    assert_equal "traceur.js", logical_path("traceur.es6", accept: "application/javascript")
  end

  def logical_path(path, options = {})
    filename = fixture_path("paths/#{path}")
    assert File.exist?(filename), "#{filename} does not exist"
    silence_warnings do
      assert asset = @env.find_asset(filename, options), "couldn't find asset: #{filename}"
      asset.logical_path
    end
  end
end

class AssetContentTypeTest < Sprockets::TestCase
  def setup
    @env = Sprockets::Environment.new
    @env.append_path(fixture_path('paths'))
  end

  test "content type" do
    assert_equal nil, content_type("empty")

    assert_equal "application/javascript", content_type("application.js")
    assert_equal "text/css", content_type("application.css")

    assert_equal "application/javascript", content_type("application.js.erb")
    assert_equal "application/javascript", content_type("application.coffee", accept: "application/javascript")
    assert_equal "text/css", content_type("application.scss", accept: "text/css")
    assert_equal "application/javascript", content_type("project.coffee.erb", accept: "application/javascript")

    assert_equal "text/css", content_type("store.css.erb")
    assert_equal "text/plain", content_type("files.erb")
    assert_equal nil, content_type("store.foo")

    assert_equal "application/javascript", content_type("application.coffee", accept: "application/javascript")
    assert_equal "text/css", content_type("application.scss", accept: "text/css")
    assert_equal "application/javascript", content_type("hello.jst.ejs")

    assert_equal "application/javascript", content_type("bower/main.js")
    assert_equal "application/json", content_type("bower/bower.json")

    assert_equal "application/javascript", content_type("coffee/index.js")
    assert_equal "application/javascript", content_type("coffee/foo.coffee", accept: "application/javascript")

    assert_equal "application/javascript", content_type("jquery.js")
    assert_equal "application/javascript", content_type("jquery.min.js")
    assert_equal "application/javascript", content_type("jquery.csv.js")
    assert_equal "application/javascript", content_type("jquery.csv.min.js")
    assert_equal "application/javascript", content_type("jquery.foo.min.js")
    assert_equal "application/javascript", content_type("jquery.tmpl.js")
    assert_equal "application/javascript", content_type("jquery.tmpl.min.js")
    assert_equal "application/javascript", content_type("jquery.ext/index.js")
    assert_equal "application/javascript", content_type("jquery.ext/form.js")
    assert_equal "application/javascript", content_type("jquery-coffee.min.coffee", accept: "application/javascript")
    assert_equal "application/javascript", content_type("jquery-custom.min.js.erb")
    assert_equal nil, content_type("jquery.js.min")

    assert_equal "application/javascript", content_type("all.coffee/plain.js")
    assert_equal "application/javascript", content_type("all.coffee/hot.coffee", accept: "application/javascript")
    assert_equal "application/javascript", content_type("all.coffee/index.coffee", accept: "application/javascript")

    assert_equal "application/javascript", content_type("foo-ng.ngt")
    assert_equal "application/javascript", content_type("bar-ng.ngt.haml")
    assert_equal "application/javascript", content_type("baz-ng.js.ngt")

    assert_equal nil, content_type("sprite.css.embed")

    assert_equal "application/javascript", content_type("traceur.es6", accept: "application/javascript")
  end

  def content_type(path, options = {})
    filename = fixture_path("paths/#{path}")
    assert File.exist?(filename), "#{filename} does not exist"
    silence_warnings do
      assert asset = @env.find_asset(filename, options), "couldn't find asset: #{filename}"
      asset.content_type
    end
  end
end
