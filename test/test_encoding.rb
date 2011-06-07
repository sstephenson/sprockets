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
      assert_equal Encoding.find('ASCII'), data.encoding
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
      assert_equal "var foo = \"bar\";\nvar snowman = \"\342\230\203\";\n",
        data
      assert_equal Encoding.find('UTF-8'), data.encoding
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
      assert_equal "var foo = \"bar\";\nvar snowman = \"\342\230\203\";\n",
        @env['ascii_utf8.js'].to_s
    end
  end
end
