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
  def entries(dirname)
    if $dir_entires_calls
      $dir_entires_calls[dirname.to_s] ||= 0
      $dir_entires_calls[dirname.to_s] += 1

      if $DEBUG && $dir_entires_calls[dirname.to_s] > 1
        warn "Multiple Dir.entries(#{dirname.to_s.inspect}) calls"
        warn caller.join("\n")
      end
    end
    original_entries(dirname)
  end
end

class TestPerformance < Sprockets::TestCase
  def setup
    @env = Sprockets::Environment.new(".")
    @env.append_path(fixture_path('default'))

    $file_stat_calls = {}
    $dir_entires_calls = {}
  end

  def teardown
    $file_stat_calls = nil
    $dir_entires_calls = nil
  end

  test "simple file" do
    @env.with_index do
      @env["gallery.js"].to_s
    end
    assert_no_redundant_stat_calls
  end

  test "indexed simple file" do
    @env.index["gallery.js"].to_s
    assert_no_redundant_stat_calls
  end

  test "file with deps" do
    @env.with_index do
      @env["mobile.js"].to_s
    end
    assert_no_redundant_stat_calls
  end

  test "indexed file with deps" do
    @env.index["mobile.js"].to_s
    assert_no_redundant_stat_calls
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
