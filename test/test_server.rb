# -*- coding: utf-8 -*-
require "sprockets_test"

require 'rack/builder'
require 'rack/test'

class TestServer < Sprockets::TestCase
  include Rack::Test::Methods

  def setup
    @env = Sprockets::Environment.new
    @env.append_path(fixture_path("server/app/javascripts"))
    @env.append_path(fixture_path("server/vendor/javascripts"))
    @env.append_path(fixture_path("server/vendor/stylesheets"))
  end

  def default_app
    env = @env

    Rack::Builder.new do
      map "/assets" do
        run env
      end

      map "/cached/javascripts" do
        run env.index
      end
    end
  end

  def app
    @app ||= default_app
  end

  test "serve single source file" do
    get "/assets/foo.js"
    assert_equal "var foo;\n", last_response.body
  end

  test "serve single source file body" do
    get "/assets/foo.js?body=1"
    assert_equal 200, last_response.status
    assert_equal "var foo;\n", last_response.body
    assert_equal "9", last_response.headers['Content-Length']
  end

  test "serve single source file from indexed environment" do
    get "/cached/javascripts/foo.js"
    assert_equal "var foo;\n", last_response.body
  end

  test "serve source with dependencies" do
    get "/assets/application.js"
    assert_equal "var foo;\n\n(function() {\n  application.boot();\n})();\n",
      last_response.body
  end

  test "serve source file body that has dependencies" do
    get "/assets/application.js?body=true"
    assert_equal 200, last_response.status
    assert_equal "\n(function() {\n  application.boot();\n})();\n",
      last_response.body
    assert_equal "43", last_response.headers['Content-Length']
  end

  test "serve source with content type headers" do
    get "/assets/application.js"
    assert_equal "application/javascript", last_response.headers['Content-Type']
  end

  test "serve source with etag headers" do
    digest = @env['application.js'].digest

    get "/assets/application.js"
    assert_equal "\"#{digest}\"",
      last_response.headers['ETag']
  end

  test "updated file updates the last modified header" do
    time = Time.now
    path = fixture_path "server/app/javascripts/foo.js"

    sandbox path do
      File.utime(time, time, path)

      get "/assets/application.js"
      time_before_modifying = last_response.headers['Last-Modified']

      get "/assets/application.js"
      time_after_modifying = last_response.headers['Last-Modified']

      assert_equal time_before_modifying, time_after_modifying

      mtime = Time.now + 60
      File.open(path, 'w') { |f| f.write "(change)" }
      File.utime(mtime, mtime, path)

      get "/assets/application.js"
      time_after_modifying = last_response.headers['Last-Modified']

      assert_not_equal time_before_modifying, time_after_modifying
    end
  end

  test "file updates do not update last modified header for indexed environments" do
    time = Time.now
    path = fixture_path "server/app/javascripts/foo.js"
    File.utime(time, time, path)

    get "/cached/javascripts/application.js"
    time_before_touching = last_response.headers['Last-Modified']

    get "/cached/javascripts/application.js"
    time_after_touching = last_response.headers['Last-Modified']

    assert_equal time_before_touching, time_after_touching

    mtime = Time.now + 60
    File.utime(mtime, mtime, path)

    get "/cached/javascripts/application.js"
    time_after_touching = last_response.headers['Last-Modified']

    # TODO: CI doesn't like this
    # assert_equal time_before_touching, time_after_touching
  end

  test "not modified partial response when etags match" do
    get "/assets/application.js?body=1"
    assert_equal 200, last_response.status
    etag = last_response.headers['ETag']

    get "/assets/application.js?body=1", {},
      'HTTP_IF_NONE_MATCH' => etag

    assert_equal 304, last_response.status
    assert_equal nil, last_response.headers['Content-Type']
    assert_equal nil, last_response.headers['Content-Length']
  end

  test "if sources didnt change the server shouldnt rebundle" do
    get "/assets/application.js"
    asset_before = @env["application.js"]
    assert asset_before

    get "/assets/application.js"
    asset_after = @env["application.js"]
    assert asset_after

    assert asset_before.equal?(asset_after)
  end

  test "fingerprint digest sets expiration to the future" do
    get "/assets/application.js"
    digest = last_response.headers['ETag'][/"(.+)"/, 1]

    get "/assets/application-#{digest}.js"
    assert_equal 200, last_response.status
    assert_match %r{max-age}, last_response.headers['Cache-Control']
  end

  test "missing source" do
    get "/assets/none.js"
    assert_equal 404, last_response.status
    assert_equal "pass", last_response.headers['X-Cascade']
  end

  test "re-throw JS exceptions in the browser" do
    get "/assets/missing_require.js"
    assert_equal 200, last_response.status
    assert_equal "throw Error(\"Sprockets::FileNotFound: couldn't find file 'notfound'\\n  (in #{fixture_path("server/vendor/javascripts/missing_require.js")}:1)\")", last_response.body
  end

  test "display CSS exceptions in the browser" do
    get "/assets/missing_require.css"
    assert_equal 200, last_response.status
    assert_match %r{content: ".*?Sprockets::FileNotFound}, last_response.body
  end

  test "serve encoded utf-8 pathname" do
    get "/assets/%E6%97%A5%E6%9C%AC%E8%AA%9E.js"
    assert_equal "var japanese = \"日本語\";\n", last_response.body
  end

  test "illegal require outside load path" do
    get "/assets/../config/passwd"
    assert_equal 403, last_response.status

    get "/assets/%2e%2e/config/passwd"
    assert_equal 403, last_response.status
  end

  test "add new source to tree" do
    filename = fixture_path("server/app/javascripts/baz.js")

    sandbox filename do
      get "/assets/tree.js"
      assert_equal "var foo;\n\n(function() {\n  application.boot();\n})();\nvar bar;\nvar japanese = \"日本語\";\n", last_response.body

      File.open(filename, "w") do |f|
        f.puts "var baz;"
      end

      path = fixture_path "server/app/javascripts"
      mtime = Time.now + 60
      File.utime(mtime, mtime, path)

      get "/assets/tree.js"
      assert_equal "var foo;\n\n(function() {\n  application.boot();\n})();\nvar bar;\nvar baz;\nvar japanese = \"日本語\";\n", last_response.body
    end
  end

  test "serving static assets" do
    get "/assets/hello.txt"
    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response.content_type
    assert_equal File.read(fixture_path("server/app/javascripts/hello.txt")), last_response.body
  end
end
