# -*- coding: utf-8 -*-
require 'sprockets_test'
require 'sprockets/path_utils'

class TestPathUtils < Sprockets::TestCase
  include Sprockets::PathUtils

  test "stat" do
    assert_kind_of File::Stat, stat(FIXTURE_ROOT)
    refute stat("/tmp/sprockets/missingfile")
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

  test "normalize path" do
    assert_equal "foo", normalize_path("foo")
    assert_equal "foo/bar", normalize_path("foo/bar")
    assert_equal "foo/bar/baz", normalize_path("foo/bar/baz")

    assert_equal fixture_path("root/foo/bar/baz"),
      normalize_path("./foo/bar/baz", fixture_path("root/main"))
    assert_equal fixture_path("foo/bar"), normalize_path("../foo/bar", fixture_path("root/main"))

    assert_raises TypeError do
      normalize_path("./foo")
    end
    assert_raises TypeError do
      normalize_path("../foo")
    end
  end

  test "split paths root from base" do
    assert_equal [fixture_path("default"), "application.js"],
      paths_split([fixture_path("default")], fixture_path("default/application.js"))
    assert_equal [fixture_path("default"), "app/application.js"],
      paths_split([fixture_path("default")], fixture_path("default/app/application.js"))
    refute paths_split([fixture_path("default")], fixture_path("other/app/application.js"))
  end

  test "path reverse extensions enumerator" do
    assert_equal [".txt"], path_reverse_extnames("hello.txt").to_a
    assert_equal [".txt"], path_reverse_extnames("sub/hello.txt").to_a
    assert_equal [".txt"], path_reverse_extnames("sub.dir/hello.txt").to_a
    assert_equal [".js"], path_reverse_extnames("jquery.js").to_a
    assert_equal [".js", ".min"], path_reverse_extnames("jquery.min.js").to_a
    assert_equal [".erb", ".js"], path_reverse_extnames("jquery.js.erb").to_a
    assert_equal [".erb", ".js", ".min"], path_reverse_extnames("jquery.min.js.erb").to_a
  end

  test "stat directory" do
    assert_equal 26, stat_directory(File.join(FIXTURE_ROOT, "default")).to_a.size
    path, stat = stat_directory(File.join(FIXTURE_ROOT, "default")).first
    assert_equal fixture_path("default/app"), path
    assert_kind_of File::Stat, stat

    assert_equal [], stat_directory(File.join(FIXTURE_ROOT, "missing")).to_a
  end

  test "stat tree" do
    assert_equal 51, stat_tree(File.join(FIXTURE_ROOT, "default")).to_a.size
    path, stat = stat_tree(File.join(FIXTURE_ROOT, "default")).first
    assert_equal fixture_path("default/app"), path
    assert_kind_of File::Stat, stat

    assert_equal [], stat_tree(File.join(FIXTURE_ROOT, "missing")).to_a
  end

  test "read unicode" do
    assert_equal "var foo = \"bar\";\n",
      read_unicode_file(fixture_path('encoding/ascii.js'))
    assert_equal "var snowman = \"☃\";",
      read_unicode_file(fixture_path('encoding/utf8.js'))
    assert_equal "var snowman = \"☃\";",
      read_unicode_file(fixture_path('encoding/utf8_bom.js'))

    assert_raises Sprockets::EncodingError do
      read_unicode_file(fixture_path('encoding/utf16.js'))
    end
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
