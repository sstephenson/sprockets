require 'minitest/autorun'
require 'sprockets/path_dependency_utils'

class TestPathDependencyUtils < MiniTest::Test
  include Sprockets::PathDependencyUtils

  def test_entries_with_dependencies
    path = File.expand_path("../fixtures", __FILE__)
    filenames, deps = entries_with_dependencies(path)
    assert_kind_of Array, filenames
    assert filenames.size > 1
    assert_equal [build_file_digest_uri(path)], deps.to_a

    path = "/tmp/sprockets/missingdir"
    filenames, deps = entries_with_dependencies(path)
    assert_kind_of Array, filenames
    assert filenames.empty?
    assert_equal [build_file_digest_uri(path)], deps.to_a
  end

  FILES_IN_SERVER = Dir["#{File.expand_path("../fixtures/server", __FILE__)}/*"]

  def test_stat_directory_with_dependencies
    dirname = File.expand_path("../fixtures/server", __FILE__)
    filenames, deps = stat_directory_with_dependencies(dirname)
    assert_equal FILES_IN_SERVER.size, filenames.size
    assert_equal [build_file_digest_uri(dirname)], deps.to_a

    path, stat = filenames.first
    assert_equal File.expand_path("../fixtures/server/app", __FILE__), path
    assert_kind_of File::Stat, stat

    dirname = File.expand_path("../fixtures/missing", __FILE__)
    filenames, deps = stat_directory_with_dependencies(dirname)
    assert_equal [], filenames
    assert_equal [build_file_digest_uri(dirname)], deps.to_a
  end

  def test_stat_sorted_tree_with_dependencies
    dirname = File.expand_path("../fixtures/asset/tree/all", __FILE__)
    filenames, deps = stat_sorted_tree_with_dependencies(dirname)
    assert_equal 11, filenames.size
    assert_equal [
      File.expand_path("../fixtures/asset/tree/all", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/b", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/b/c", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/d", __FILE__)
    ].map { |p| build_file_digest_uri(p) }, deps.to_a

    path, stat = filenames.first
    assert_equal File.expand_path("../fixtures/asset/tree/all/README.md", __FILE__), path
    assert_kind_of File::Stat, stat

    assert_equal [
      File.expand_path("../fixtures/asset/tree/all/README.md", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/b.css", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/b.js.erb", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/b", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/b/c.js", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/b/c", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/b/c/d.js", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/b/c/e.js", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/d", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/d/c.coffee", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/d/e.js", __FILE__),
    ], filenames.map(&:first)

    dirname = File.expand_path("../fixtures/missing", __FILE__)
    filenames, deps = stat_sorted_tree_with_dependencies(dirname)
    assert_equal [], filenames
    assert_equal [build_file_digest_uri(dirname)], deps.to_a
  end
end
