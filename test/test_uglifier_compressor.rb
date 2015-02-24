require 'sprockets_test'
require 'sprockets/cache'
require 'sprockets/uglifier_compressor'

class TestUglifierCompressor < Sprockets::TestCase
  test "compress javascript" do
    input = {
      content_type: 'application/javascript',
      data: "function foo() {\n  return true;\n}",
      cache: Sprockets::Cache.new,
      metadata: {
        map: SourceMap::Map.new
      }
    }
    output = "function foo(){return!0}"
    result = Sprockets::UglifierCompressor.call(input)
    assert_equal output, result[:data]
  end

  test "cache key" do
    assert Sprockets::UglifierCompressor.cache_key
  end
end
