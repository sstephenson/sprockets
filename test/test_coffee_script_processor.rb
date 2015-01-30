require 'sprockets_test'
require 'sprockets/coffee_script_processor'

class TestCoffeeScriptProcessor < Sprockets::TestCase
  test "compile coffee-script template to js" do
    input = {
      content_type: 'application/javascript',
      data: "square = (n) -> n * n",
      cache: Sprockets::Cache.new
    }
    assert Sprockets::CoffeeScriptProcessor.call(input).match(/var square/)
  end

  test "compile coffee-script template with source map" do
    input = {
      content_type: 'application/javascript',
      data: "square = (n) -> n * n",
      name: 'squared',
      cache: Sprockets::Cache.new,
      map: SourceMap::Map.new
    }
    result = Sprockets::CoffeeScriptProcessor.call(input)
    assert result[:data].match(/var square/)
    assert_equal 19, result[:map].size
    assert_equal ['squared'], result[:map].sources
  end

  test "cache key" do
    assert Sprockets::CoffeeScriptProcessor.cache_key
  end
end
