# -*- coding: utf-8 -*-
require "sprockets_test"

class EncodingTest < Sprockets::TestCase
  def setup
    @env = Sprockets::Environment.new
    @env.append_path(fixture_path('encoding'))
  end

  if "".respond_to?(:encoding)
    test "read ASCII asset" do
      data = @env['ascii.js'].to_s
      assert_equal "var foo = \"bar\";\n", data
      assert_equal Encoding.find('UTF-8'), data.encoding
    end

    test "read UTF-8 asset" do
      data = @env['utf8.js'].to_s
      assert_equal "var snowman = \"☃\";\n", data
      assert_equal Encoding.find('UTF-8'), data.encoding
    end

    test "read UTF-8 asset with BOM" do
      data = @env['utf8_bom.js'].to_s
      assert_equal "var snowman = \"☃\";\n", data.encode("UTF-8")
      assert_equal Encoding.find('UTF-8'), data.encoding
    end

    test "read UTF-16 asset" do
      assert_raise Sprockets::EncodingError do
        @env['utf16.js'].to_s
      end
    end

    test "read ASCII + UTF-8 concatation asset" do
      data = @env['ascii_utf8.js'].to_s
      assert_equal "var foo = \"bar\";\nvar snowman = \"\342\230\203\";\n\n\n",
        data
      assert_equal Encoding.find('UTF-8'), data.encoding
    end

    test "read static BINARY asset" do
      data = @env['binary.png'].to_s
      assert_equal "\x89PNG\r\n\x1A\n\x00\x00\x00".force_encoding("BINARY"),
        data[0..10]
      assert_equal Encoding.find('BINARY'), data.encoding
    end

    test "read processed BINARY asset" do
      @env.register_postprocessor('image/png', :noop_processor) { |context, data| data }
      data = @env['binary.png'].to_s
      assert_equal "\x89PNG\r\n\x1A\n\x00\x00\x00".force_encoding("BINARY"),
        data[0..10]
      assert_equal Encoding.find('BINARY'), data.encoding
    end
  else
    test "read ASCII asset" do
      assert_equal "var foo = \"bar\";\n", @env['ascii.js'].to_s
    end

    test "read UTF-8 asset" do
      assert_equal "var snowman = \"\342\230\203\";\n", @env['utf8.js'].to_s
    end

    test "read UTF-8 asset with BOM" do
      assert_equal "var snowman = \"\342\230\203\";\n", @env['utf8_bom.js'].to_s
    end

    test "read UTF-16 asset" do
      assert_raise Sprockets::EncodingError do
        @env['utf16.js'].to_s
      end
    end

    test "read ASCII + UTF-8 concatation asset" do
      assert_equal "var foo = \"bar\";\nvar snowman = \"\342\230\203\";\n\n\n",
        @env['ascii_utf8.js'].to_s
    end

    test "read static BINARY asset" do
      data = @env['binary.png'].to_s
      assert_equal "\x89PNG\r\n\x1A\n\x00\x00\x00", data[0..10]
    end

    test "read processed BINARY asset" do
      @env.register_postprocessor('image/png', :noop_processor) { |context, data| data }
      data = @env['binary.png'].to_s
      assert_equal "\x89PNG\r\n\x1A\n\x00\x00\x00", data[0..10]
    end
  end
end
