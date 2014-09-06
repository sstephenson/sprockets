# -*- coding: utf-8 -*-
require 'sprockets_test'
require 'sprockets/path_utils'

class TestPathUtils < Sprockets::TestCase
  include Sprockets::PathUtils

  test "stat" do
    assert_kind_of File::Stat, stat(FIXTURE_ROOT)
    refute stat("/tmp/sprockets/missingfile")
  end

  test "file?" do
    assert_equal true, file?(File.join(FIXTURE_ROOT, 'default', 'hello.txt'))
    assert_equal false, file?(FIXTURE_ROOT)
  end

  test "entries" do
    assert_equal [
      "asset",
      "compass",
      "context",
      "default",
      "directives",
      "encoding",
      "engines",
      "errors",
      "paths",
      "public",
      "resolve",
      "sass",
      "server",
      "symlink"
    ], entries(FIXTURE_ROOT)
  end

  test "check absolute path" do
    assert absolute_path?("/foo.rb")
    refute absolute_path?("foo.rb")
    refute absolute_path?("./foo.rb")
    refute absolute_path?("../foo.rb")
  end

  test "check relative path" do
    assert relative_path?(".")
    assert relative_path?("..")
    assert relative_path?("./")
    assert relative_path?("../")
    assert relative_path?("./foo.rb")
    assert relative_path?("../foo.rb")
    refute relative_path?("/foo.rb")
    refute relative_path?("foo.rb")
    refute relative_path?(".foo.rb")
    refute relative_path?("..foo.rb")
  end

  test "split subpath from root path" do
    assert_equal "application.js",
      split_subpath(fixture_path("default"), fixture_path("default/application.js"))
    assert_equal "application.js",
      split_subpath(fixture_path("default") + "/", fixture_path("default/application.js"))
    assert_equal "app/application.js",
      split_subpath(fixture_path("default"), fixture_path("default/app/application.js"))
    refute split_subpath(fixture_path("default"), fixture_path("other/app/application.js"))
  end

  test "split paths root from base" do
    assert_equal [fixture_path("default"), "application.js"],
      paths_split([fixture_path("default")], fixture_path("default/application.js"))
    assert_equal [fixture_path("default"), "app/application.js"],
      paths_split([fixture_path("default")], fixture_path("default/app/application.js"))
    refute paths_split([fixture_path("default")], fixture_path("other/app/application.js"))
  end

  test "path with /../" do
    assert_nil paths_split([fixture_path("default")], fixture_path("default/../../../../application.js"))
  end

  test "path extensions" do
    assert_equal [".txt"], path_extnames("hello.txt")
    assert_equal [".txt"], path_extnames("sub/hello.txt")
    assert_equal [".txt"], path_extnames("sub.dir/hello.txt")
    assert_equal [".js"], path_extnames("jquery.js")
    assert_equal [".min", ".js"], path_extnames("jquery.min.js")
    assert_equal [".js", ".erb"], path_extnames("jquery.js.erb")
    assert_equal [".min", ".js", ".erb"], path_extnames("jquery.min.js.erb")
  end

  FILES_IN_DEFAULT = Dir["#{FIXTURE_ROOT}/default/*"].size

  test "stat directory" do
    assert_equal FILES_IN_DEFAULT, stat_directory(File.join(FIXTURE_ROOT, "default")).to_a.size
    path, stat = stat_directory(File.join(FIXTURE_ROOT, "default")).first
    assert_equal fixture_path("default/app"), path
    assert_kind_of File::Stat, stat

    assert_equal [], stat_directory(File.join(FIXTURE_ROOT, "missing")).to_a
  end

  SYMLINKS_UNDER_DEFAULT = 6
  FILES_UNDER_DEFAULT = Dir["#{FIXTURE_ROOT}/default/**/*"].size + SYMLINKS_UNDER_DEFAULT

  test "stat tree" do
    assert_equal FILES_UNDER_DEFAULT, stat_tree(File.join(FIXTURE_ROOT, "default")).to_a.size
    path, stat = stat_tree(File.join(FIXTURE_ROOT, "default")).first
    assert_equal fixture_path("default/app"), path
    assert_kind_of File::Stat, stat

    assert_equal [], stat_tree(File.join(FIXTURE_ROOT, "missing")).to_a
  end

  test "atomic write without errors" do
    filename = "atomic.file"
    begin
      contents = "Atomic Text"
      atomic_write(filename, Dir.pwd) do |file|
        file.write(contents)
        assert !File.exist?(filename)
      end
      assert File.exist?(filename)
      assert_equal contents, File.read(filename)
    ensure
      File.unlink(filename) rescue nil
    end
  end
end
