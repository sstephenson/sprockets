require 'sprockets_test'
require 'sprockets/es6to5_processor'

class TestES6to5Processor < Sprockets::TestCase
  test "compile ES6 features to ES5" do
    input = {
      content_type: 'application/ecmascript-6',
      data: "const square = (n) => n * n",
      cache: Sprockets::Cache.new
    }

    assert js = Sprockets::ES6to5Processor.call(input)
    assert_match(/var square/, js)
    assert_match(/function/, js)
  end
end
