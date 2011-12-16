require 'sprockets_test'
require 'shellwords'
require 'tmpdir'

class TestSprocketize < Sprockets::TestCase
  def setup
    @dir = File.join(Dir::tmpdir, 'sprocketize')
  end

  def teardown
    # FileUtils.rm_rf(@dir)
    # wtf, dunno
    system "rm -rf #{@dir}"
    assert Dir["#{@dir}/*"].empty?
  end

  test "show version for -v flag" do
    output = sprocketize "-v"
    assert_equal "#{Sprockets::VERSION}\n", output
  end

  test "show help for -h flag" do
    output = sprocketize "-h"
    assert_match "Usage: sprocketize", output
  end

  test "show help for no flags or inputs" do
    output = sprocketize
    assert_match "Usage: sprocketize", output
  end

  test "compile simple file" do
    output = sprocketize fixture_path("default/gallery.js")
    assert_equal "var Gallery = {};\n", output
  end

  test "compile file with dependencies" do
    output = sprocketize "-I", fixture_path("asset"), fixture_path("asset/application.js")
    assert_equal "var Project = {\n  find: function(id) {\n  }\n};\nvar Users = {\n  find: function(id) {\n  }\n};\n\n\n\ndocument.on('dom:loaded', function() {\n  $('search').focus();\n});\n", output
  end

  test "compile asset to output directory" do
    output = sprocketize "-I", fixture_path("default"), "-o", @dir, fixture_path("default/gallery.js")
    assert_equal "", output
    assert File.exist?("#{@dir}/manifest.json")
    assert File.exist?("#{@dir}/gallery-14c3b648520bac7a78379b54161c8a9e.js")
  end

  def sprocketize(*args)
    script = File.expand_path("../../bin/sprockets", __FILE__)
    lib    = File.expand_path("../../lib", __FILE__)
    `ruby -I#{lib} #{script} #{Shellwords.join(args)}`
  end
end
