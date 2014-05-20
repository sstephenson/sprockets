require 'sprockets_test'
require 'sprockets/utils'

class TestUtils < Sprockets::TestCase
  include Sprockets::Utils

  test "hexdigest" do
    assert_equal "ab316bb112a477fa409c3020d34c2f2878fda76b", hexdigest(nil)
    assert_equal "c91653ddbc97ebc06ce8f74455132acb0796489c", hexdigest(true)
    assert_equal "1c8d0066bc059dae1626bf94d132c0890b3fe5e7", hexdigest(false)
    assert_equal "f675e4b8f6d361f6636c71ca8c5dbc1d35582925", hexdigest(42)
    assert_equal "cece4709cf686f8c8b62ad61adc4da8f75bf8a0f", hexdigest("foo")
    assert_equal "b2817f7211c00bd368a2be200af4f1dd9ac74877", hexdigest(:foo)
    assert_equal "a8442a027898a77c7b30fc41785141685d14701b", hexdigest([])
    assert_equal "e3c69947361aad09ce9927bc0f622ee36063cdb6", hexdigest(["foo"])
    assert_equal "838038ad67c6d3392dbdf6325a6e32846f0c3071", hexdigest({"foo" => "bar"})
    assert_equal "eca5033f779fad6ce036f1cf962563c09acfd0c8", hexdigest({"foo" => "baz"})
    assert_equal "fa22d4603e816bde8d0d77efe13e8b97d4ba8668", hexdigest([[:foo, 1]])
    assert_equal "a050c68845181bb89ffa2f988c200ba425de0034", hexdigest([{:foo => 1}])
  end
end
