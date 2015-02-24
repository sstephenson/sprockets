require 'minitest/autorun'
require 'sprockets/path_utils'

class TestPathUtils < MiniTest::Test
  include Sprockets::PathUtils

  DOSISH = File::ALT_SEPARATOR != nil
  DOSISH_DRIVE_LETTER = File.dirname("A:") == "A:."
  DOSISH_UNC = File.dirname("//") == "//"

  def test_stat
    assert_kind_of File::Stat, stat(File.expand_path("../fixtures", __FILE__))
    refute stat("/tmp/sprockets/missingfile")
  end

  def test_file
    assert_equal true, file?(File.expand_path("../fixtures/default/hello.txt", __FILE__))
    assert_equal false, file?(File.expand_path("../fixtures", __FILE__))
  end

  def test_entries
    assert_equal [
      "asset",
      "compass",
      "context",
      "default",
      "directives",
      "encoding",
      "errors",
      "octicons",
      "paths",
      "public",
      "resolve",
      "sass",
      "server",
      "source-maps",
      "symlink"
    ], entries(File.expand_path("../fixtures", __FILE__))

    assert_equal [], entries("/tmp/sprockets/missingdir")
  end

  def test_check_absolute_path
    assert absolute_path?(Dir.pwd)

    assert absolute_path?("/foo.rb")
    refute absolute_path?("foo.rb")
    refute absolute_path?("./foo.rb")
    refute absolute_path?("../foo.rb")

    if DOSISH_DRIVE_LETTER
      assert absolute_path?("A:foo.rb")
      assert absolute_path?("A:/foo.rb")
      assert absolute_path?("A:\\foo.rb")
    end

    if DOSISH
      assert absolute_path?("/foo.rb")
      assert absolute_path?("\\foo.rb")
    end
  end

  def test_check_relative_path
    assert relative_path?(".")
    assert relative_path?("..")
    assert relative_path?("./")
    assert relative_path?("../")
    assert relative_path?("./foo.rb")
    assert relative_path?("../foo.rb")

    if DOSISH
      assert relative_path?(".\\")
      assert relative_path?("..\\")
      assert relative_path?(".\\foo.rb")
      assert relative_path?("..\\foo.rb")
    end

    refute relative_path?(Dir.pwd)
    refute relative_path?("/foo.rb")
    refute relative_path?("foo.rb")
    refute relative_path?(".foo.rb")
    refute relative_path?("..foo.rb")
  end

  def test_split_subpath_from_root_path
    path = File.expand_path("../fixtures/default", __FILE__)

    subpath = File.expand_path("../fixtures/default/application.js", __FILE__)
    assert_equal "application.js", split_subpath(path, subpath)

    subpath = File.expand_path("../fixtures/default/application.js", __FILE__)
    assert_equal "application.js", split_subpath(path + "/", subpath)

    subpath = File.expand_path("../fixtures/default/app/application.js", __FILE__)
    assert_equal "app/application.js", split_subpath(path, subpath)

    subpath = File.expand_path("../fixtures/default", __FILE__)
    assert_equal "", split_subpath(path, subpath)

    subpath = File.expand_path("../fixtures/other/app/application.js", __FILE__)
    refute split_subpath(path, subpath)
  end

  def test_split_paths_root_from_base
    paths = [File.expand_path("../fixtures/default", __FILE__)]

    filename = File.expand_path("../fixtures/default/application.js", __FILE__)
    expected = [paths.first, "application.js"]
    assert_equal expected, paths_split(paths, filename)

    filename = File.expand_path("../fixtures/default/app/application.js", __FILE__)
    expected = [paths.first, "app/application.js"]
    assert_equal expected, paths_split(paths, filename)

    filename = File.expand_path("../fixtures/default", __FILE__)
    expected = [paths.first, ""]
    assert_equal expected, paths_split(paths, filename)

    filename = File.expand_path("../fixtures/other/app/application.js", __FILE__)
    refute paths_split(paths, filename)
  end

  def test_path_extensions
    assert_equal [".txt"], path_extnames("hello.txt")
    assert_equal [".txt"], path_extnames("sub/hello.txt")
    assert_equal [".txt"], path_extnames("sub.dir/hello.txt")
    assert_equal [".js"], path_extnames("jquery.js")
    assert_equal [".min", ".js"], path_extnames("jquery.min.js")
    assert_equal [".js", ".erb"], path_extnames("jquery.js.erb")
    assert_equal [".min", ".js", ".erb"], path_extnames("jquery.min.js.erb")
  end

  def test_match_path_extname
    extensions = { ".txt" => "text/plain" }
    assert_equal [".txt", "text/plain"], match_path_extname("hello.txt", extensions)
    assert_equal [".txt", "text/plain"], match_path_extname("sub/hello.txt", extensions)
    refute match_path_extname("hello.text", extensions)

    extensions = { ".js" => "application/javascript" }
    assert_equal [".js", "application/javascript"], match_path_extname("jquery.js", extensions)
    assert_equal [".js", "application/javascript"], match_path_extname("jquery.min.js", extensions)
    refute match_path_extname("jquery.js.erb", extensions)
    refute match_path_extname("jquery.min.js.erb", extensions)

    extensions = { ".js" => "application/javascript", ".js.erb" => "application/javascript+ruby" }
    assert_equal [".js", "application/javascript"], match_path_extname("jquery.js", extensions)
    assert_equal [".js", "application/javascript"], match_path_extname("jquery.min.js", extensions)
    assert_equal [".js.erb", "application/javascript+ruby"], match_path_extname("jquery.js.erb", extensions)
    assert_equal [".js.erb", "application/javascript+ruby"], match_path_extname("jquery.min.js.erb", extensions)
    refute match_path_extname("jquery.min.coffee.erb", extensions)

    extensions = { ".js.map" => "application/json", ".css.map" => "application/json" }
    assert_equal [".js.map", "application/json"], match_path_extname("jquery.js.map", extensions)
    assert_equal [".js.map", "application/json"], match_path_extname("jquery.min.js.map", extensions)
    assert_equal [".css.map", "application/json"], match_path_extname("jquery-ui.css.map", extensions)
    assert_equal [".css.map", "application/json"], match_path_extname("jquery-ui.min.css.map", extensions)
    refute match_path_extname("jquery.map", extensions)
    refute match_path_extname("jquery.map.js", extensions)
    refute match_path_extname("jquery.map.css", extensions)
  end

  def test_path_parents
    root = File.expand_path("../..", __FILE__)

    assert_kind_of Array, path_parents(File.expand_path(__FILE__))

    assert_equal ["#{root}/test", root],
      path_parents(File.expand_path(__FILE__), root)
    assert_equal ["#{root}/test", root],
      path_parents("#{root}/test/fixtures/", root)
    assert_equal ["#{root}/test/fixtures", "#{root}/test", root],
      path_parents("#{root}/test/fixtures/default", root)
    assert_equal ["#{root}/test/fixtures/default", "#{root}/test/fixtures", "#{root}/test", root],
      path_parents("#{root}/test/fixtures/default/POW.png", root)

    assert_equal ["#{root}/test/fixtures/default", "#{root}/test/fixtures", "#{root}/test"],
      path_parents("#{root}/test/fixtures/default/POW.png", "#{root}/test")
    assert_equal ["#{root}/test/fixtures/default"],
      path_parents("#{root}/test/fixtures/default/POW.png", "#{root}/test/fixtures/default")
  end

  def test_find_upwards
    root = File.expand_path("../..", __FILE__)

    assert_equal "#{root}/Gemfile",
      find_upwards("Gemfile", File.expand_path(__FILE__))
    assert_equal "#{root}/Gemfile",
      find_upwards("Gemfile", "#{root}/test/fixtures/")
    assert_equal "#{root}/Gemfile",
      find_upwards("Gemfile", "#{root}/test/fixtures/default/POW.png")

    assert_equal "#{root}/test/sprockets_test.rb",
      find_upwards("sprockets_test.rb", "#{root}/test/fixtures/default/POW.png")
  end

  FILES_IN_SERVER = Dir["#{File.expand_path("../fixtures/server", __FILE__)}/*"]

  def test_stat_directory
    files = stat_directory(File.expand_path("../fixtures/server", __FILE__)).to_a
    assert_equal FILES_IN_SERVER.size, files.size
    path, stat = stat_directory(File.expand_path("../fixtures/server", __FILE__)).first
    assert_equal File.expand_path("../fixtures/server/app", __FILE__), path
    assert_kind_of File::Stat, stat

    assert_equal [], stat_directory(File.expand_path("../fixtures/missing", __FILE__)).to_a
  end

  def test_stat_tree
    files = stat_tree(File.expand_path("../fixtures/asset/tree/all", __FILE__)).to_a
    assert_equal 11, files.size

    path, stat = files.first
    assert_equal File.expand_path("../fixtures/asset/tree/all/README.md", __FILE__), path
    assert_kind_of File::Stat, stat

    assert_equal [
      File.expand_path("../fixtures/asset/tree/all/README.md", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/b", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/b/c", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/b/c/d.js", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/b/c/e.js", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/b/c.js", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/b.css", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/b.js.erb", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/d", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/d/c.coffee", __FILE__),
      File.expand_path("../fixtures/asset/tree/all/d/e.js", __FILE__)
    ], files.map(&:first)

    assert_equal [], stat_tree("#{File.expand_path("../fixtures", __FILE__)}/missing").to_a
  end

  def test_stat_sorted_tree
    files = stat_sorted_tree(File.expand_path("../fixtures/asset/tree/all", __FILE__)).to_a
    assert_equal 11, files.size

    path, stat = files.first
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
      File.expand_path("../fixtures/asset/tree/all/d/e.js", __FILE__)
    ], files.map(&:first)

    assert_equal [], stat_tree(File.expand_path("../fixtures/missing", __FILE__)).to_a
  end

  def test_atomic_write_without_errors
    filename = "atomic.file"
    begin
      contents = "Atomic Text"
      atomic_write(filename) do |file|
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
