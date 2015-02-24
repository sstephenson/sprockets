require "sprockets_test"

class AssetEncodingTest < Sprockets::TestCase
  def setup
    @env = Sprockets::Environment.new
    @env.append_path(fixture_path('encoding'))
  end

  test "read ASCII asset" do
    data = @env['ascii.js'].to_s
    assert_equal "var foo = \"bar\";\n", data
    assert_equal Encoding::UTF_8, data.encoding
  end

  test "read UTF-8 asset" do
    data = @env['utf8.js'].to_s
    assert_equal "var snowman = \"☃\";\n", data
    assert_equal Encoding::UTF_8, data.encoding
  end

  test "read UTF-8 asset with BOM" do
    data = @env['utf8_bom.js'].to_s
    assert_equal "var snowman = \"☃\";\n", data
    assert_equal Encoding::UTF_8, data.encoding
  end

  test "read UTF-16 asset" do
    data = @env['utf16le.js'].to_s
    assert_equal "var snowman = \"☃\";\n", data
    assert_equal Encoding::UTF_8, data.encoding
  end

  test "read ASCII + UTF-8 concatation asset" do
    data = @env['ascii_utf8.js'].to_s
    assert_equal "var foo = \"bar\";\nvar snowman = \"\342\230\203\";\n\n\n",
      data
    assert_equal Encoding::UTF_8, data.encoding
  end

  test "read static BINARY asset" do
    data = @env['binary.png'].to_s
    assert_equal "\x89PNG\r\n\x1A\n\x00\x00\x00".force_encoding("BINARY"),
      data[0..10]
    assert_equal Encoding::BINARY, data.encoding
  end

  test "read processed BINARY asset" do
    @env.register_postprocessor('image/png') { |input| input[:data] }
    data = @env['binary.png'].to_s
    assert_equal "\x89PNG\r\n\x1A\n\x00\x00\x00".force_encoding("BINARY"),
      data[0..10]
    assert_equal Encoding::BINARY, data.encoding
  end

  test "read css asset with charset" do
    expected = "\n\nh1 { color: red; }\n"
    assert_equal expected, @env['utf8-charset.css'].to_s
    assert_equal expected, @env['utf16le-charset.css'].to_s
    assert_equal expected, @env['utf16le-bom-charset.css'].to_s
  end

  test "read file with content type" do
    data = @env.read_file(fixture_path('encoding/ascii.js'), 'application/javascript')
    assert_equal "var foo = \"bar\";\n", data
    assert_equal Encoding::UTF_8, data.encoding

    data = @env.read_file(fixture_path('encoding/utf16le-charset.css'), 'text/css')
    assert_equal "\n\nh1 { color: red; }\n", data
    assert_equal Encoding::UTF_8, data.encoding
  end
end
