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

  test "resolve multistep transform type for svg" do
    noop = proc {}

    assert_equal 'test/svg', @env.resolve_transform_type('test/svg', 'test/svg')
    assert_equal 'test/png', @env.resolve_transform_type('test/png', 'test/png')
    assert_equal 'test/jpg', @env.resolve_transform_type('test/jpg', 'test/jpg')
    assert_equal 'test/gif', @env.resolve_transform_type('test/gif', 'test/gif')
    assert_equal 'test/tif', @env.resolve_transform_type('test/tif', 'test/tif')
    assert_equal 'test/jif', @env.resolve_transform_type('test/jif', 'test/jif')

    refute @env.resolve_transform_type('test/svg', 'test/png')
    refute @env.resolve_transform_type('test/svg', 'test/jpg')
    refute @env.resolve_transform_type('test/svg', 'test/gif')
    refute @env.resolve_transform_type('test/svg', 'test/tif')
    refute @env.resolve_transform_type('test/svg', 'test/jif')

    @env.register_transformer 'test/svg', 'test/png', noop
    assert_equal 'test/png', @env.resolve_transform_type('test/svg', 'test/png')
    refute @env.resolve_transform_type('test/svg', 'test/jpg')
    refute @env.resolve_transform_type('test/svg', 'test/gif')
    refute @env.resolve_transform_type('test/svg', 'test/tif')
    refute @env.resolve_transform_type('test/svg', 'test/jif')

    @env.register_transformer 'test/svg', 'test/jpg', noop
    assert_equal 'test/png', @env.resolve_transform_type('test/svg', 'test/png')
    assert_equal 'test/jpg', @env.resolve_transform_type('test/svg', 'test/jpg')
    refute @env.resolve_transform_type('test/svg', 'test/gif')
    refute @env.resolve_transform_type('test/svg', 'test/tif')
    refute @env.resolve_transform_type('test/svg', 'test/jif')
    refute @env.resolve_transform_type('test/png', 'test/jpg')

    @env.register_transformer 'test/jpg', 'test/gif', noop
    assert_equal 'test/png', @env.resolve_transform_type('test/svg', 'test/png')
    assert_equal 'test/jpg', @env.resolve_transform_type('test/svg', 'test/jpg')
    assert_equal 'test/gif', @env.resolve_transform_type('test/jpg', 'test/gif')
    assert_equal 'test/gif', @env.resolve_transform_type('test/svg', 'test/gif')
    refute @env.resolve_transform_type('test/svg', 'test/tif')
    refute @env.resolve_transform_type('test/svg', 'test/jif')
    refute @env.resolve_transform_type('test/png', 'test/jpg')
    refute @env.resolve_transform_type('test/png', 'test/gif')

    @env.register_transformer 'test/gif', 'test/tif', noop
    assert_equal 'test/png', @env.resolve_transform_type('test/svg', 'test/png')
    assert_equal 'test/jpg', @env.resolve_transform_type('test/svg', 'test/jpg')
    assert_equal 'test/gif', @env.resolve_transform_type('test/jpg', 'test/gif')
    assert_equal 'test/gif', @env.resolve_transform_type('test/svg', 'test/gif')
    assert_equal 'test/tif', @env.resolve_transform_type('test/gif', 'test/tif')
    assert_equal 'test/tif', @env.resolve_transform_type('test/jpg', 'test/tif')
    assert_equal 'test/tif', @env.resolve_transform_type('test/svg', 'test/tif')
    refute @env.resolve_transform_type('test/svg', 'test/jif')
    refute @env.resolve_transform_type('test/png', 'test/jpg')
    refute @env.resolve_transform_type('test/png', 'test/gif')
    refute @env.resolve_transform_type('test/png', 'test/tif')

    @env.register_transformer 'test/tif', 'test/jif', noop
    assert_equal 'test/png', @env.resolve_transform_type('test/svg', 'test/png')
    assert_equal 'test/jpg', @env.resolve_transform_type('test/svg', 'test/jpg')
    assert_equal 'test/gif', @env.resolve_transform_type('test/jpg', 'test/gif')
    assert_equal 'test/gif', @env.resolve_transform_type('test/svg', 'test/gif')
    assert_equal 'test/tif', @env.resolve_transform_type('test/gif', 'test/tif')
    assert_equal 'test/tif', @env.resolve_transform_type('test/jpg', 'test/tif')
    assert_equal 'test/tif', @env.resolve_transform_type('test/svg', 'test/tif')
    assert_equal 'test/jif', @env.resolve_transform_type('test/jpg', 'test/jif')
    assert_equal 'test/jif', @env.resolve_transform_type('test/gif', 'test/jif')
    assert_equal 'test/jif', @env.resolve_transform_type('test/tif', 'test/jif')
    assert_equal 'test/jif', @env.resolve_transform_type('test/svg', 'test/jif')
    refute @env.resolve_transform_type('test/png', 'test/jpg')
    refute @env.resolve_transform_type('test/png', 'test/gif')
    refute @env.resolve_transform_type('test/png', 'test/tif')
    refute @env.resolve_transform_type('test/png', 'test/jif')
  end

  test "expand transform accepts" do
    assert_equal [
      ['text/plain', 1.0],
      ['application/plain+ruby', 0.8]
    ], @env.expand_transform_accepts(@env.parse_q_values('text/plain'))
    assert_equal [
      ['application/javascript', 1.0],
      ['application/ecmascript-6', 0.8],
      ['text/coffeescript', 0.8],
      ['text/eco', 0.8], # TODO: Extra step transform should be weighted down
      ['text/ejs', 0.8], # TODO: Extra step transform should be weighted down
      ['application/javascript+function', 0.8],
      ['application/ecmascript-6+ruby', 0.8],
      ['application/javascript+ruby', 0.8],
      ['application/coffeescript+ruby', 0.8],
      ['text/mustache', 0.8], # TODO: Extra step transform should be weighted down
      ['text/x-handlebars-template', 0.8], # TODO: Extra step transform should be weighted down
      ['application/dart', 0.8]
    ], @env.expand_transform_accepts(@env.parse_q_values('application/javascript'))
    assert_equal [['image/png', 1.0], ['image/svg+xml', 0.8]],
      @env.expand_transform_accepts(@env.parse_q_values('image/png'))
  end

  test "compose transformers" do
    transformers = {
      "image/svg" => {
        "image/png" => proc { |input| { data: input[:data] + ",svg->png" } }
      },
      "image/png" => {
        "image/gif" => proc { |input| { data: input[:data] + ",png->gif" } }
      }
    }

    processor = @env.compose_transformers(transformers, ["image/svg", "image/png"])
    assert_equal({data: ",svg->png"}, processor.call({data: ""}))

    processor = @env.compose_transformers(transformers, ["image/svg", "image/png", "image/gif"])
    assert_equal({data: ",svg->png,png->gif"}, processor.call({data: ""}))

    assert_raises(Sprockets::ArgumentError) do
      @env.compose_transformers(transformers, ["image/svg"])
    end

    assert_raises(Sprockets::ArgumentError) do
      @env.compose_transformers(transformers, ["image/svg", "image/jif"])
    end
  end
end
