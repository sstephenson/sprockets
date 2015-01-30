require 'sprockets_test'
require 'sprockets/cache'
require 'sprockets/uglifier_compressor'

class TestUglifierCompressor < Sprockets::TestCase
  test "compress javascript" do
    input = {
      content_type: 'application/javascript',
      data: "function foo() {\n  return true;\n}",
      cache: Sprockets::Cache.new,
      metadata: {}
    }
    output = "function foo(){return!0}"
    assert_equal output, Sprockets::UglifierCompressor.call(input)
  end

  test "cache key" do
    assert Sprockets::UglifierCompressor.cache_key
  end
end
