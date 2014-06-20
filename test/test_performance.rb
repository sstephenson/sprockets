require 'sprockets_test'

$file_stat_calls = nil
class << File
  alias_method :original_stat, :stat
  def stat(filename)
    if $file_stat_calls
      $file_stat_calls[filename.to_s] ||= 0
      $file_stat_calls[filename.to_s] += 1
    end
    original_stat(filename)
  end
end

$dir_entires_calls = nil
class << Dir
  alias_method :original_entries, :entries
  def entries(dirname, *args)
    if $dir_entires_calls
      $dir_entires_calls[dirname.to_s] ||= 0
      $dir_entires_calls[dirname.to_s] += 1
    end
    original_entries(dirname, *args)
  end
end

class TestPerformance < Sprockets::TestCase
  class Cache
    def initialize
      @cache = {}
    end

    def get(key)
      $cache_get_calls[key] ||= 0
      $cache_get_calls[key] += 1
      @cache[key]
    end

    def set(key, value)
      $cache_set_calls[key] ||= 0
      $cache_set_calls[key] += 1
      @cache[key] = value
    end
  end

  def setup
    @env = new_environment
    reset_stats!
  end

  def teardown
    $file_stat_calls = nil
    $dir_entires_calls = nil
    $processor_calls = nil
    $cache_get_calls = nil
    $cache_set_calls = nil
  end

  test "simple file" do
    @env["gallery.js"].to_s
    assert_no_redundant_stat_calls
    assert_no_redundant_processor_calls
  end

  test "cached simple file" do
    @env.cached["gallery.js"].to_s
    assert_no_redundant_stat_calls
    assert_no_redundant_processor_calls
  end

  test "file with deps" do
    @env["mobile.js"].to_s
    assert_no_redundant_stat_calls
    assert_no_redundant_processor_calls
  end

  test "cached file with deps" do
    @env.cached["mobile.js"].to_s
    assert_no_redundant_stat_calls
    assert_no_redundant_processor_calls
  end

  test "loading from backend cache" do
    env1, env2 = new_environment, new_environment
    cache = Cache.new
    env1.cache = cache
    env2.cache = cache

    env1["mobile.js"]
    assert_no_redundant_processor_calls
    assert_no_redundant_cache_set_calls

    reset_stats!

    env2["mobile.js"]
    assert_no_redundant_stat_calls
    assert_no_processor_calls
    assert_no_redundant_cache_get_calls
    assert_no_cache_set_calls
  end

  test "loading from instance cache" do
    env = @env.cached
    env["mobile.js"]
    assert_no_redundant_processor_calls

    reset_stats!

    env["mobile.js"]
    assert_no_stat_calls
    assert_no_processor_calls
  end

  test "loading from cached with backend cache" do
    env1, env2 = new_environment, new_environment
    cache = Cache.new
    env1.cache = cache
    env2.cache = cache

    env1.cached["mobile.js"]
    assert_no_redundant_processor_calls
    assert_no_redundant_cache_set_calls

    reset_stats!

    env2.cached["mobile.js"]
    assert_no_redundant_stat_calls
    assert_no_processor_calls
    assert_no_redundant_cache_get_calls
    assert_no_cache_set_calls
  end

  def new_environment
    Sprockets::Environment.new(".") do |env|
      env.cache = Cache.new
      env.append_path(fixture_path('default'))
      env.register_preprocessor 'application/javascript', proc { |input|
        $processor_calls[input[:filename]] ||= 0
        $processor_calls[input[:filename]] += 1
        nil
      }
    end
  end

  def reset_stats!
    $file_stat_calls = {}
    $dir_entires_calls = {}
    $processor_calls = {}
    $cache_get_calls = {}
    $cache_set_calls = {}
  end

  def assert_no_stat_calls
    $file_stat_calls.each do |path, count|
      assert_equal 0, count, "File.stat(#{path.inspect}) called #{count} times"
    end

    $dir_entires_calls.each do |path, count|
      assert_equal 0, count, "Dir.entries(#{path.inspect}) called #{count} times"
    end
  end

  def assert_no_redundant_stat_calls
    $file_stat_calls.each do |path, count|
      assert_equal 1, count, "File.stat(#{path.inspect}) called #{count} times"
    end

    $dir_entires_calls.each do |path, count|
      assert_equal 1, count, "Dir.entries(#{path.inspect}) called #{count} times"
    end
  end

  def assert_no_processor_calls
    $processor_calls.each do |path, count|
      assert_equal 0, count, "Processor ran on #{path.inspect} #{count} times"
    end
  end

  def assert_no_redundant_processor_calls
    $processor_calls.each do |path, count|
      assert_equal 1, count, "Processor ran on #{path.inspect} #{count} times"
    end
  end

  def assert_no_redundant_cache_get_calls
    $cache_get_calls.each do |key, count|
      assert_equal 1, count, "cache get #{key.inspect} #{count} times"
    end
  end

  def assert_no_cache_set_calls
    $cache_set_calls.each do |key, count|
      assert_equal 0, count, "cache set #{key.inspect} #{count} times"
    end
  end

  def assert_no_redundant_cache_set_calls
    $cache_set_calls.each do |key, count|
      assert_equal 1, count, "cache set #{key.inspect} #{count} times"
    end
  end
end
