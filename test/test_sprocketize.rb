require 'sprockets_test'
require 'shellwords'
require 'tmpdir'

class TestSprockets < Sprockets::TestCase
  def setup
    @env = Sprockets::Environment.new(".") do |env|
      env.append_path(fixture_path('default'))
    end

    @dir = File.join(Dir::tmpdir, 'sprockets')
  end

  def teardown
    # FileUtils.rm_rf(@dir)
    # wtf, dunno
    system "rm -rf #{@dir}"
    assert Dir["#{@dir}/*"].empty?
  end

  test "show version for -v flag" do
    output = sprockets "-v"
    assert_equal "#{Sprockets::VERSION}\n", output
  end

  test "show help for -h flag" do
    output = sprockets "-h"
    assert_match "Usage: sprockets", output
  end

  test "show help for no flags or inputs" do
    output = sprockets
    assert_match "Usage: sprockets", output
  end

  test "error if load path is missing" do
    sprockets fixture_path("default/gallery.js")
    assert_equal 1, $?.exitstatus
  end

  test "compile simple file" do
    output = sprockets "-I", fixture_path("default"), fixture_path("default/gallery.js")
    assert_equal "var Gallery = {};\n", output
  end

  test "show error if multiple files are given" do
    sprockets fixture_path("default/gallery.js"), fixture_path("default/application.js")
    assert_equal 1, $?.exitstatus
  end

  test "compile file with dependencies" do
    output = sprockets "-I", fixture_path("asset"), fixture_path("asset/application.js")
    assert_equal "var Project = {\n  find: function(id) {\n  }\n};\nvar Users = {\n  find: function(id) {\n  }\n};\n\n\n\ndocument.on('dom:loaded', function() {\n  $('search').focus();\n});\n", output
  end

  test "compile asset to output directory" do
    digest_path = @env['gallery.js'].digest_path
    output = sprockets "-I", fixture_path("default"), "-o", @dir, fixture_path("default/gallery.js")
    assert_equal "", output
    assert Dir["#{@dir}/manifest-*.json"].first
    assert File.exist?("#{@dir}/#{digest_path}")
  end

  test "compile multiple assets to output directory" do
    digest_path1, digest_path2 = @env['gallery.js'].digest_path, @env['gallery.css'].digest_path
    output = sprockets "-I", fixture_path("default"), "-o", @dir, "gallery.js", "gallery.css"
    assert_equal "", output
    assert Dir["#{@dir}/manifest-*.json"].first
    assert File.exist?("#{@dir}/#{digest_path1}")
    assert File.exist?("#{@dir}/#{digest_path2}")
  end

  test "minify js with uglify" do
    output = sprockets "-I", fixture_path("default"), "--js-compressor", "uglify", "gallery.js"
    assert_equal "var Gallery={};\n", output
  end

  test "compress css with sass" do
    output = sprockets "-I", fixture_path("default"), "--css-compressor", "sass", "gallery.css"
    assert_equal ".gallery{color:red}\n", output
  end

  def sprockets(*args)
    script = File.expand_path("../../bin/sprockets", __FILE__)
    lib    = File.expand_path("../../lib", __FILE__)
    `ruby -I#{lib} #{script} #{Shellwords.join(args)} 2>&1`
  end
end
