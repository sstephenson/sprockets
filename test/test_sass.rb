require 'sprockets_test'

class TestBaseSass < Sprockets::TestCase
  CACHE_PATH = File.expand_path("../../.sass-cache", __FILE__)
  COMPASS_PATH = File.join(FIXTURE_ROOT, 'compass')

  def setup
    silence_warnings do
      require 'sass'
    end
  end

  def teardown
    FileUtils.rm_r(CACHE_PATH) if File.exist?(CACHE_PATH)
    assert !File.exist?(CACHE_PATH)
  end

  def silence_warnings
    old_verbose, $VERBOSE = $VERBOSE, false
    yield
  ensure
    $VERBOSE = old_verbose
  end
end

class TestSprocketsSass < TestBaseSass
  def setup
    super

    @env = Sprockets::Environment.new(".") do |env|
      env.cache = {}
      env.append_path(fixture_path('.'))
      env.append_path(fixture_path('compass'))
    end
  end

  def teardown
    assert !File.exist?(CACHE_PATH)
  end

  def render(path)
    path = fixture_path(path)
    silence_warnings do
      @env[path].to_s
    end
  end

  test "process variables" do
    assert_equal <<-EOS, render('sass/variables.sass')
.content-navigation {
  border-color: #3bbfce;
  color: #2ca2af; }

.border {
  padding: 8px;
  margin: 8px;
  border-color: #3bbfce; }
    EOS
  end

  test "process nesting" do
    assert_equal <<-EOS, render('sass/nesting.scss')
table.hl {
  margin: 2em 0; }
  table.hl td.ln {
    text-align: right; }

li {
  font-family: serif;
  font-weight: bold;
  font-size: 1.2em; }
    EOS
  end

  test "@import scss partial from scss" do
    assert_equal <<-EOS, render('sass/import_partial.scss')
#navbar li {
  border-top-radius: 10px;
  -moz-border-radius-top: 10px;
  -webkit-border-top-radius: 10px; }

#footer {
  border-top-radius: 5px;
  -moz-border-radius-top: 5px;
  -webkit-border-top-radius: 5px; }

#sidebar {
  border-left-radius: 8px;
  -moz-border-radius-left: 8px;
  -webkit-border-left-radius: 8px; }
    EOS
  end

  test "@import scss partial from sass" do
    assert_equal <<-EOS, render('sass/import_partial.sass')
#navbar li {
  border-top-radius: 10px;
  -moz-border-radius-top: 10px;
  -webkit-border-top-radius: 10px; }

#footer {
  border-top-radius: 5px;
  -moz-border-radius-top: 5px;
  -webkit-border-top-radius: 5px; }

#sidebar {
  border-left-radius: 8px;
  -moz-border-radius-left: 8px;
  -webkit-border-left-radius: 8px; }
    EOS
  end

  test "@import sass non-partial from scss" do
    assert_equal <<-EOS, render('sass/import_nonpartial.scss')
.content-navigation {
  border-color: #3bbfce;
  color: #2ca2af; }

.border {
  padding: 8px;
  margin: 8px;
  border-color: #3bbfce; }
    EOS
  end

  test "@import css file from load path" do
    assert_equal <<-EOS, render('sass/import_load_path.scss')
    EOS
  end

  test "process css file" do
    assert_equal <<-EOS, render('sass/reset.css')
article, aside, details, figcaption, figure,
footer, header, hgroup, menu, nav, section {
  display: block; }
    EOS
  end

  test "@import relative file" do
    assert_equal <<-EOS, render('sass/shared/relative.scss')
#navbar li {
  border-top-radius: 10px;
  -moz-border-radius-top: 10px;
  -webkit-border-top-radius: 10px; }

#footer {
  border-top-radius: 5px;
  -moz-border-radius-top: 5px;
  -webkit-border-top-radius: 5px; }

#sidebar {
  border-left-radius: 8px;
  -moz-border-radius-left: 8px;
  -webkit-border-left-radius: 8px; }
    EOS
  end

  test "@import relative nested file" do
    assert_equal <<-EOS, render('sass/relative.scss')
body {
  background: #666666; }
    EOS
  end

  test "modify file causes it to recompile" do
    filename = fixture_path('sass/test.scss')

    sandbox filename do
      File.open(filename, 'w') { |f| f.write "body { background: red; };" }
      assert_equal "body {\n  background: red; }\n", render(filename)

      File.open(filename, 'w') { |f| f.write "body { background: blue; };" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, filename)

      assert_equal "body {\n  background: blue; }\n", render(filename)
    end
  end

  test "modify partial causes it to recompile" do
    filename, partial = fixture_path('sass/test.scss'), fixture_path('sass/_partial.scss')

    sandbox filename, partial do
      File.open(filename, 'w') { |f| f.write "@import 'partial';" }
      File.open(partial, 'w') { |f| f.write "body { background: red; };" }
      assert_equal "body {\n  background: red; }\n", render(filename)

      File.open(partial, 'w') { |f| f.write "body { background: blue; };" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, partial)

      assert_equal "body {\n  background: blue; }\n", render(filename)
    end
  end

  test "reference @import'd variable" do
    assert_equal <<-EOS, render('sass/links.scss')
a:link {
  color: "red"; }
    EOS
  end

  test "@import reference variable" do
    assert_equal <<-EOS, render('sass/main.scss')
#header {
  color: "blue"; }
    EOS
  end
end

class TestSassCompressor < TestBaseSass
  test "compress css" do
    silence_warnings do
      uncompressed = "p {\n  margin: 0;\n  padding: 0;\n}\n"
      compressed   = "p{margin:0;padding:0}\n"
      assert_equal compressed, Sprockets::SassCompressor.new("foo.css") { uncompressed }.render(Object.new)
    end
  end
end

class TestSassFunctions < TestSprocketsSass
  def setup
    super

    @env.context_class.class_eval do
      def asset_path(path, options = {})
        "/#{path}"
      end
    end
  end

  test "path functions" do
    assert_equal <<-EOS, render('sass/paths.scss')
div {
  url: url("/foo.svg");
  url: url("/foo.png");
  url: url("/foo.mov");
  url: url("/foo.mp3");
  url: url("/foo.woff");
  url: url("/foo.js");
  url: url("/foo.css"); }
    EOS
  end

  test "url functions" do
    assert_equal <<-EOS, render('sass/urls.scss')
div {
  url: url(/foo.svg);
  url: url(/foo.png);
  url: url(/foo.mov);
  url: url(/foo.mp3);
  url: url(/foo.woff);
  url: url(/foo.js);
  url: url(/foo.css); }
    EOS
  end
end
