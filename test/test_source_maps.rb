require 'sprockets_test'
require 'sprockets/bundle'

silence_warnings do
  require 'sass'
end

class TestSourceMaps < Sprockets::TestCase
  def setup
    @env = Sprockets::Environment.new
    @env.append_path fixture_path('source-maps')
  end

  test "builds a source map for js files" do
    asset = @env['child.js']
    map = asset.metadata[:map]
    assert_equal ['child.js'], map.sources
  end

  test "builds a minified source map" do
    @env.js_compressor = :uglifier

    asset = @env['application.js']
    map = asset.metadata[:map]
    assert map.all? {|mapping| mapping.generated.line == 1 }
    assert_equal %w(project.coffee users.coffee application.coffee), map.sources
  end

  test "builds a source map with js dependency" do
    asset = @env['parent.js']
    map = asset.metadata[:map]
    assert_equal %w(child.js users.coffee parent.js), map.sources
  end

  test "compile coffeescript source map" do
    assert asset = @env.find_asset("coffee/main.js")
    assert_equal fixture_path('source-maps/coffee/main.coffee'), asset.filename
    assert_equal "application/javascript", asset.content_type

    assert_match "(function() {", asset.source
    assert_match "Math.sqrt", asset.source

    assert asset = @env.find_asset("coffee/main.js.map")
    assert_equal fixture_path('source-maps/coffee/main.coffee'), asset.filename

    assert map = JSON.parse(asset.source)
    assert_equal({
      "version" => 3,
      "file" => "",
      "mappings" => "AADA;AAAA,MAAA,sDAAA;IAAA,kBAAA;;AAAA,EAAA,MAAA,GAAA,EAAA,CAAA;;AAAA,EAAA,QAAA,GAAA,IAAA,CAAA;;AAAA,EAAA,IAAA,QAAA;AAAA,IAAA,MAAA,GAAA,CAAA,EAAA,CAAA;GAAA;;AAAA,EAAA,MAAA,GAAA,SAAA,CAAA,GAAA;WAAA,CAAA,GAAA,EAAA;EAAA,CAAA,CAAA;;AAAA,EAAA,IAAA,GAAA,CAAA,CAAA,EAAA,CAAA,EAAA,CAAA,EAAA,CAAA,EAAA,CAAA,CAAA,CAAA;;AAAA,EAAA,IAAA,GAAA;AAAA,IAAA,IAAA,EAAA,IAAA,CAAA,IAAA;AAAA,IAAA,MAAA,EAAA,MAAA;AAAA,IAAA,IAAA,EAAA,SAAA,CAAA,GAAA;aAAA,CAAA,GAAA,MAAA,CAAA,CAAA,EAAA;IAAA,CAAA;GAAA,CAAA;;AAAA,EAAA,IAAA,GAAA,SAAA,GAAA;AAAA,QAAA,eAAA;AAAA,IAAA,uBAAA,iEAAA,CAAA;WAAA,KAAA,CAAA,MAAA,EAAA,OAAA,EAAA;EAAA,CAAA,CAAA;;AAAA,EAAA,IAAA,8CAAA;AAAA,IAAA,KAAA,CAAA,YAAA,CAAA,CAAA;GAAA;;AAAA,EAAA,KAAA;;AAAA;SAAA,2CAAA;qBAAA;AAAA,oBAAA,IAAA,CAAA,IAAA,CAAA,GAAA,EAAA,CAAA;AAAA;;MAAA,CAAA;AAAA",
      "sources" => ["coffee/main.coffee"],
      "names" => []
    }, map)
  end

  test "use precompiled coffeescript source map" do
    assert asset = @env.find_asset("coffee/precompiled/main.js")
    assert_equal fixture_path('source-maps/coffee/precompiled/main.js'), asset.filename
    assert_equal "application/javascript", asset.content_type

    assert_match "(function() {", asset.source
    assert_match "Math.sqrt", asset.source

    assert asset = @env.find_asset("coffee/precompiled/main.js.map")
    assert_equal fixture_path('source-maps/coffee/precompiled/main.js.map'), asset.filename

    assert map = JSON.parse(asset.source)
    assert_equal 3, map['version']
    assert_equal "main.js", map['file']
    assert_equal 779, map['mappings'].size
  end

  test "compile scss source map" do
    asset = silence_warnings do
      @env.find_asset("sass/main.css")
    end
    assert asset
    assert_equal fixture_path('source-maps/sass/main.scss'), asset.filename
    assert_equal "text/css", asset.content_type

    assert_match "nav a {", asset.source

    asset = silence_warnings do
      @env.find_asset("sass/main.css.map")
    end
    assert asset
    assert_equal fixture_path('source-maps/sass/main.scss'), asset.filename

    assert map = JSON.parse(asset.source)
    assert_equal({
      "version" => 3,
      "file" => "sass/main.css",
      "mappings" => "",
      "sources" => ["sass/main.scss"],
      "names" => []
    }, map)
  end

  test "use precompiled scss source map" do
    asset = silence_warnings do
      @env.find_asset("sass/precompiled/main.css")
    end
    assert asset
    assert_equal fixture_path('source-maps/sass/precompiled/main.css'), asset.filename
    assert_equal "text/css", asset.content_type

    assert_match "nav a {", asset.source

    asset = silence_warnings do
      @env.find_asset("sass/precompiled/main.css.map")
    end
    assert asset
    assert_equal fixture_path('source-maps/sass/precompiled/main.css.map'), asset.filename

    assert map = JSON.parse(asset.source)
    assert_equal 3, map['version']
    assert_equal "main.css", map['file']
    assert_equal 172, map['mappings'].size
  end
end
