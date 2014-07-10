require 'sprockets_test'
require 'sprockets/coffee_script_template'

class TestCoffeeScriptTemplate < Sprockets::TestCase
  test "compile coffee-script template to js" do
    input = {
      content_type: 'application/javascript',
      data: "square = (n) -> n * n",
      cache: Sprockets::Cache.new
    }
    assert Sprockets::CoffeeScriptTemplate.call(input).match(/var square/)
  end

  test "compile coffee-script template with source map" do
    input = {
      content_type: 'application/javascript',
      data: "square = (n) -> n * n",
      cache: Sprockets::Cache.new,
      map: SourceMap::Map.new
    }
    result = Sprockets::CoffeeScriptTemplate.call(input)
    assert result[:data].match(/var square/)
    assert_equal 19, result[:map].size
  end
end
