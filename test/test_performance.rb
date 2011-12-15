require 'sprockets_test'

$file_stat_calls = nil
class << File
  alias_method :original_stat, :stat
  def stat(filename)
    if $file_stat_calls
      $file_stat_calls[filename.to_s] ||= 0
      $file_stat_calls[filename.to_s] += 1

      if $DEBUG && $file_stat_calls[filename.to_s] > 1
        warn "Multiple File.stat(#{filename.to_s.inspect}) calls"
        warn caller.join("\n")
      end
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

      if $DEBUG && $dir_entires_calls[dirname.to_s] > 1
        warn "Multiple Dir.entries(#{dirname.to_s.inspect}) calls"
        warn caller.join("\n")
      end
    end
    original_entries(dirname, *args)
  end
end

class TestPerformance < Sprockets::TestCase
  def setup
    @env = new_environment
    reset_stats!
  end

  def teardown
    $file_stat_calls = nil
    $dir_entires_calls = nil
  end

  test "simple file" do
    @env["gallery.js"].to_s
    assert_no_redundant_stat_calls
  end

  test "indexed simple file" do
    @env.index["gallery.js"].to_s
    assert_no_redundant_stat_calls
  end

  test "file with deps" do
    @env["mobile.js"].to_s
    assert_no_redundant_stat_calls
  end

  test "indexed file with deps" do
    @env.index["mobile.js"].to_s
    assert_no_redundant_stat_calls
  end

  test "checking freshness" do
    asset = @env["mobile.js"]
    reset_stats!

    assert asset.fresh?(@env)
    assert_no_redundant_stat_calls
  end

  test "checking freshness of from index" do
    index = @env.index
    asset = index["mobile.js"]
    reset_stats!

    assert asset.fresh?(index)
    assert_no_stat_calls
  end

  test "loading from cache" do
    env1, env2 = new_environment, new_environment
    env1.cache = {}
    env2.cache = {}

    env1["mobile.js"]
    reset_stats!

    env2["mobile.js"]
    assert_no_redundant_stat_calls
  end

  test "loading from indexed cache" do
    env1, env2 = new_environment, new_environment
    env1.cache = {}
    env2.cache = {}

    env1.index["mobile.js"]
    reset_stats!

    env2.index["mobile.js"]
    assert_no_redundant_stat_calls
  end

  def new_environment
    Sprockets::Environment.new(".") do |env|
      env.append_path(fixture_path('default'))
    end
  end

  def reset_stats!
    $file_stat_calls = {}
    $dir_entires_calls = {}
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
end
