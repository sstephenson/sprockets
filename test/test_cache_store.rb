require 'sprockets_test'
require 'tmpdir'

module CacheStoreNullTests
  def test_read
    refute @store["foo"]
  end

  def test_write
    result = @store["foo"] = "bar"
    assert_equal "bar", result
  end

  def test_write_and_read_miss
    @store["foo"] = "bar"
    refute @store["foo"]
  end
end

module CacheStoreTests
  def test_read_miss
    refute @store["missing"]
  end

  def test_write
    result = @store["foo"] = "bar"
    assert_equal "bar", result
  end

  def test_write_and_read_hit
    @store["foo"] = "bar"
    assert_equal "bar", @store["foo"]
  end

  def test_multiple_write_and_read_hit
    @store["foo"] = "1"
    @store["bar"] = "2"
    @store["baz"] = "3"

    assert_equal "1", @store["foo"]
    assert_equal "2", @store["bar"]
    assert_equal "3", @store["baz"]
  end

  def test_delete
    @store["foo"] = "bar"
    assert_equal "bar", @store["foo"]
    @store["foo"] = nil
    assert_equal nil, @store["foo"]
  end
end

class TestNullStore < Sprockets::TestCase
  def setup
    @store = Sprockets::Cache::NullStore.new
  end

  include CacheStoreNullTests
end

class TestMemoryStore < Sprockets::TestCase
  def setup
    @store = Sprockets::Cache::MemoryStore.new
  end

  include CacheStoreTests
end

class TestZeroMemoryStore < Sprockets::TestCase
  def setup
    @store = Sprockets::Cache::MemoryStore.new(0)
  end

  include CacheStoreNullTests
end

class TestFileStore < Sprockets::TestCase
  def setup
    @root = File.join(Dir::tmpdir, "sprockets-file-store")
    @store = Sprockets::Cache::FileStore.new(@root)
  end

  include CacheStoreTests

  def test_raise
    @store["foo"] = "bar"
    # messing up with the marshalled data
    File.write(File.join(@root, "foo.cache"), "w") { |file| file.write("boom") }
    assert_equal nil, @store["foo"]
  end
end

class TestZeroFileStore < Sprockets::TestCase
  def setup
    @store = Sprockets::Cache::FileStore.new(File.join(Dir::tmpdir, "sprockets-file-store-zero"), 0)
  end

  include CacheStoreNullTests
end
