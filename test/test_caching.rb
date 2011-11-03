require 'sprockets_test'

class TestCaching < Sprockets::TestCase
  def setup
    @cache = {}

    @env1 = Sprockets::Environment.new(fixture_path('default')) do |env|
      env.append_path(".")
      env.cache = @cache
    end

    @env2 = Sprockets::Environment.new(fixture_path('symlink')) do |env|
      env.append_path(".")
      env.cache = @cache
    end
  end

  test "environment digests are the same for different roots" do
    assert_equal @env1.digest, @env2.digest
  end

  test "same environment instance cache objects are equal" do
    env = @env1

    asset1 = env['gallery.js']
    asset2 = env['gallery.js']

    assert asset1
    assert asset2

    assert asset1.equal?(asset2)
    assert asset2.equal?(asset1)
  end

  test "same index instance cache objects are equal" do
    index = @env1.index

    asset1 = index['gallery.js']
    asset2 = index['gallery.js']

    assert asset1
    assert asset2

    assert asset1.equal?(asset2)
    assert asset2.equal?(asset1)
  end

  test "same environment instance is cached at logical and expanded path" do
    env = @env1

    asset1 = env['gallery.js']
    asset2 = env[asset1.pathname]

    assert asset1
    assert asset2

    assert asset1.equal?(asset2)
    assert asset2.equal?(asset1)
  end

  test "same index instance is cached at logical and expanded path" do
    index = @env1.index

    asset1 = index['gallery.js']
    asset2 = index[asset1.pathname]

    assert asset1
    assert asset2

    assert asset1.equal?(asset2)
    assert asset2.equal?(asset1)
  end

  test "shared cache objects are eql" do
    asset1 = @env1['gallery.js']
    asset2 = @env2['gallery.js']

    assert asset1
    assert asset2

    assert asset1.eql?(asset2)
    assert asset2.eql?(asset1)
    assert !asset1.equal?(asset2)
  end

  test "depedencies are cached" do
    env = @env1

    parent = env['application.js']
    assert parent

    child1 = parent.to_a[0]

    assert child1
    assert_equal 'project.js', child1.logical_path

    child2 = env.find_asset(child1.pathname, :bundle => false)
    assert child2

    assert child1.equal?(child2)
    assert child2.equal?(child1)
  end

  test "proccessed and bundled assets are cached separately" do
    env = @env1
    assert_kind_of Sprockets::ProcessedAsset, env.find_asset('gallery.js', :bundle => false)
    assert_kind_of Sprockets::BundledAsset,   env.find_asset('gallery.js', :bundle => true)
    assert_kind_of Sprockets::ProcessedAsset, env.find_asset('gallery.js', :bundle => false)
    assert_kind_of Sprockets::BundledAsset,   env.find_asset('gallery.js', :bundle => true)
  end

  test "proccessed and bundled assets are cached separately on index" do
    index = @env1.index
    assert_kind_of Sprockets::ProcessedAsset, index.find_asset('gallery.js', :bundle => false)
    assert_kind_of Sprockets::BundledAsset,   index.find_asset('gallery.js', :bundle => true)
    assert_kind_of Sprockets::ProcessedAsset, index.find_asset('gallery.js', :bundle => false)
    assert_kind_of Sprockets::BundledAsset,   index.find_asset('gallery.js', :bundle => true)
  end

  test "keys are consistent even if environment digest changes" do
    @env1['gallery.js']
    old_keys = @cache.keys.sort

    @cache.clear
    @env2.version = '2.0'

    @env2['gallery.js']
    new_keys = @cache.keys.sort

    assert_equal old_keys, new_keys
  end

  test "stale cached asset isn't loaded if file is remove" do
    filename = fixture_path("default/tmp.js")

    sandbox filename do
      File.open(filename, 'w') { |f| f.puts "foo;" }
      assert_equal "foo;\n", @env1["tmp.js"].to_s

      File.unlink(filename)
      assert_nil @env2["tmp.js"]
    end
  end

  test "stale cached asset isn't loaded if depedency is changed and removed" do
    foo = fixture_path("default/foo-tmp.js")
    bar = fixture_path("default/bar-tmp.js")

    sandbox foo, bar do
      File.open(foo, 'w') { |f| f.puts "//= require bar-tmp\nfoo;" }
      File.open(bar, 'w') { |f| f.puts "bar;" }
      assert_equal "bar;\nfoo;\n", @env1["foo-tmp.js"].to_s
      assert_equal "bar;\n", @env1["bar-tmp.js"].to_s

      File.open(foo, 'w') { |f| f.puts "foo;" }
      File.unlink(bar)
      assert_equal "foo;\n", @env1["foo-tmp.js"].to_s
      assert_nil @env2["bar-tmp.js"]
    end
  end

  test "stale cached asset isn't loaded if removed from path" do
    env1 = Sprockets::Environment.new(fixture_path('default')) do |env|
      env.append_path("app")
      env.append_path("vendor")
      env.cache = @cache
    end

    env2 = Sprockets::Environment.new(fixture_path('default')) do |env|
      env.append_path("app")
      env.cache = @cache
    end

    assert_equal "jQuery;\n", env1["main.js"].to_s
    assert_equal "jQuery;\n", env1["jquery.js"].to_s
    assert env1["main.js"].fresh?(env1)

    assert_raises Sprockets::FileNotFound do
      env2["main.js"].to_s
    end
  end
end
