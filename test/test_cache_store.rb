require 'sprockets_test'
require 'tmpdir'
require 'fileutils'

module CacheStoreNullTests
  def test_read
    refute @store._get("foo")
  end

  def test_write
    result = @store._set("foo", "bar")
    assert_equal "bar", result
  end

  def test_write_and_read_miss
    @store._set("foo", "bar")
    refute @store._get("foo")
  end

  def test_fetch
    result = @store.fetch("foo") { "bar" }
    assert_equal "bar", result
  end
end

module CacheStoreTests
  def test_read_miss
    refute @store._get("missing")
  end

  def test_write
    result = @store._set("foo", "bar")
    assert_equal "bar", result
  end

  def test_write_and_read_hit
    @store._set("foo", "bar")
    assert_equal "bar", @store._get("foo")
  end

  def test_multiple_write_and_read_hit
    @store._set("foo", "1")
    @store._set("bar", "2")
    @store._set("baz", "3")

    assert_equal "1", @store._get("foo")
    assert_equal "2", @store._get("bar")
    assert_equal "3", @store._get("baz")
  end

  def test_delete
    @store._set("foo", "bar")
    assert_equal "bar", @store._get("foo")
    @store._set("foo", nil)
    assert_equal nil, @store._get("foo")
  end

  def test_fetch
    result = @store.fetch("user") { "josh" }
    assert_equal "josh", result
  end
end

class TestNullStore < Sprockets::TestCase
  def setup
    @_store = Sprockets::Cache::NullStore.new
    @store = Sprockets::Cache.new(Sprockets::Cache::NullStore.new)
  end

  def test_inspect
    assert_equal "#<Sprockets::Cache local=#<Sprockets::Cache::MemoryStore size=0/1024> store=#<Sprockets::Cache::NullStore>>", @store.inspect
    assert_equal "#<Sprockets::Cache::NullStore>", @_store.inspect
  end

  include CacheStoreNullTests
end

class TestMemoryStore < Sprockets::TestCase
  def setup
    @_store = Sprockets::Cache::MemoryStore.new
    @store = Sprockets::Cache.new(@_store)
  end

  def test_inspect
    assert_equal "#<Sprockets::Cache::MemoryStore size=0/1000>", @_store.inspect
  end

  include CacheStoreTests
end

class TestZeroMemoryStore < Sprockets::TestCase
  def setup
    @_store = Sprockets::Cache::MemoryStore.new(0)
    @store = Sprockets::Cache.new(@_store)
  end

  def test_inspect
    assert_equal "#<Sprockets::Cache::MemoryStore size=0/0>", @_store.inspect
  end

  include CacheStoreNullTests
end

class TestFileStore < Sprockets::TestCase
  def setup
    @root = Dir::mktmpdir "sprockets-file-store"
    @_store = Sprockets::Cache::FileStore.new(@root)
    @store = Sprockets::Cache.new(@_store)
  end

  def teardown
    FileUtils.rm_rf(@root)
  end

  def test_inspect
    Dir::mktmpdir "sprockets-file-store-inspect" do |dir|
      store = Sprockets::Cache::FileStore.new(dir)
      assert_equal "#<Sprockets::Cache::FileStore size=0/1000>", store.inspect
    end
  end

  def test_corrupted_read
    File.write(File.join(@root, "corrupt.cache"), "w") do |f|
      f.write("corrupt")
    end
    refute @_store.get("corrupt")
  end

  include CacheStoreTests
end

class TestZeroFileStore < Sprockets::TestCase
  def setup
    @tmpdir = Dir::mktmpdir "sprockets-file-store-zero"
    @_store = Sprockets::Cache::FileStore.new(@tmpdir, 0)
    @store = Sprockets::Cache.new(@_store)
  end

  def teardown
    FileUtils.rm_rf @tmpdir
  end

  def test_inspect
    Dir.mktmpdir "sprockets-file-store-inspect" do |dir|
      store = Sprockets::Cache::FileStore.new(dir, 0)
      assert_equal "#<Sprockets::Cache::FileStore size=0/0>", store.inspect
    end
  end

  include CacheStoreNullTests
end
