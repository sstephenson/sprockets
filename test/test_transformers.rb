require 'sprockets_test'

class TestTransformers < Sprockets::TestCase
  def setup
    @env = Sprockets::Environment.new(".")
  end

  test "resolve transform type for svg" do
    assert_equal 'image/svg+xml',
      @env.resolve_transform_type('image/svg+xml', 'image/svg+xml')
    assert_equal 'image/svg+xml',
      @env.resolve_transform_type('image/svg+xml', '*/*')
    assert_equal 'image/svg+xml',
      @env.resolve_transform_type('image/svg+xml', nil)
    assert_equal 'image/svg+xml',
      @env.resolve_transform_type('image/svg+xml', 'image/*')
    assert_equal 'image/png',
      @env.resolve_transform_type('image/svg+xml', 'image/png')
    assert_equal 'image/svg+xml',
      @env.resolve_transform_type('image/svg+xml', 'image/svg+xml, image/png')
    assert_equal 'image/png',
      @env.resolve_transform_type('image/svg+xml', 'image/png, image/svg+xml')
    assert_equal 'image/png',
      @env.resolve_transform_type('image/svg+xml', 'image/svg+xml; q=0.8, image/png')
    assert_equal 'image/svg+xml',
      @env.resolve_transform_type('image/svg+xml', 'text/yaml, image/svg+xml, image/png')
    assert_equal 'image/png',
      @env.resolve_transform_type('image/svg+xml', 'text/yaml, image/png, image/svg+xml')
    refute @env.resolve_transform_type('image/svg+xml', 'text/yaml')

    refute @env.resolve_transform_type(nil, 'image/svg+xml')
    refute @env.resolve_transform_type(nil, nil)
  end

  test "expand transform accepts" do
    assert_equal [['text/plain', 1.0]],
      @env.expand_transform_accepts(@env.parse_q_values('text/plain'))
    assert_equal [['application/javascript', 1.0], ["text/ecmascript-6", 0.8], ['text/coffeescript', 0.8]],
      @env.expand_transform_accepts(@env.parse_q_values('application/javascript'))
    assert_equal [['image/png', 1.0], ['image/svg+xml', 0.8]],
      @env.expand_transform_accepts(@env.parse_q_values('image/png'))
  end
end
