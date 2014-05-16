require "sprockets_test"

class DirectiveProcessorTests < Sprockets::TestCase
  test "HEADER_PATTERN can be overridden in DirectiveProcessor subclass" do
    class TestProcessor < Sprockets::DirectiveProcessor
      HEADER_PATTERN = /
        \A (
          (?m:\s*) (
            (-\# .* \n?)+
          )
        )+
      /x
    end

    source = <<-END.gsub(/^ {6}/, '')
      -#= depend_on_asset asset
      content
    END

    result = TestProcessor.new.send(:process_source, source)
    assert_equal "content\n", result[:data]
    assert_equal [[1, "depend_on_asset", "asset"]], result[:directives]
  end
end
