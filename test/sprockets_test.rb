require "minitest/autorun"
require "sprockets"
require "sprockets/environment"
require "fileutils"

require "coffee_script"
require "eco"
require "ejs"
require "erb"

old_verbose, $VERBOSE = $VERBOSE, false
Encoding.default_external = 'UTF-8'
Encoding.default_internal = 'UTF-8'
$VERBOSE = old_verbose

def silence_warnings
  old_verbose, $VERBOSE = $VERBOSE, false
  yield
ensure
  $VERBOSE = old_verbose
end

# Popular extensions for testing but not part of Sprockets core

module Sprockets
  register_engine '.missing', autoload_processor(:MissingProcessor, 'sprockets/missing_processor')
  register_postprocessor 'text/invalid', autoload_processor(:MissingProcessor, 'sprockets/missing_processor')
  register_preprocessor 'text/invalid', autoload_processor(:MissingProcessor, 'sprockets/missing_processor')
end

Sprockets.register_dependency_resolver "rand" do
  rand(2**100)
end

NoopProcessor = proc { |input| input[:data] }
Sprockets.register_mime_type 'text/haml', extensions: ['.haml']
Sprockets.register_engine '.haml', NoopProcessor, mime_type: 'text/html'

# Sprockets.register_mime_type 'text/ng-template', extensions: ['.ngt']
AngularProcessor = proc { |input|
  <<-EOS
$app.run(function($templateCache) {
  $templateCache.put('#{input[:name]}.html', #{input[:data].chomp.inspect});
});
  EOS
}
Sprockets.register_engine '.ngt', AngularProcessor, mime_type: 'application/javascript'

Sprockets.register_mime_type 'text/mustache', extensions: ['.mustache']
Sprockets.register_engine '.mustache', NoopProcessor, mime_type: 'application/javascript'

Sprockets.register_mime_type 'text/x-handlebars-template', extensions: ['.handlebars']
Sprockets.register_engine '.handlebars', NoopProcessor, mime_type: 'application/javascript'

Sprockets.register_mime_type 'application/dart', extensions: ['.dart']
Sprockets.register_engine '.dart', NoopProcessor, mime_type: 'application/javascript'

require 'nokogiri'

HtmlBuilderProcessor = proc { |input|
  instance_eval <<-EOS
    builder = Nokogiri::HTML::Builder.new do |doc|
      #{input[:data]}
    end
    builder.to_html
  EOS
}
Sprockets.register_mime_type 'application/html+builder', extensions: ['.html.builder']
Sprockets.register_transformer 'application/html+builder', 'text/html', HtmlBuilderProcessor

XmlBuilderProcessor = proc { |input|
  instance_eval <<-EOS
    builder = Nokogiri::XML::Builder.new do |xml|
      #{input[:data]}
    end
    builder.to_xml
  EOS
}
Sprockets.register_mime_type 'application/xml+builder', extensions: ['.xml.builder']
Sprockets.register_transformer 'application/xml+builder', 'application/xml', XmlBuilderProcessor

require 'sprockets/jst_processor'
Sprockets.register_engine '.jst2', Sprockets::JstProcessor.new(namespace: 'this.JST2'), mime_type: 'application/javascript'

SVG2PNG = proc { |input|
  "\x89\x50\x4e\x47\xd\xa\x1a\xa#{input[:data]}"
}
Sprockets.register_transformer 'image/svg+xml', 'image/png', SVG2PNG

CSS2HTMLIMPORT = proc { |input|
  "<style>#{input[:data]}</style>"
}
Sprockets.register_transformer 'text/css', 'text/html', CSS2HTMLIMPORT

JS2HTMLIMPORT = proc { |input|
  "<script>#{input[:data]}</script>"
}
Sprockets.register_transformer 'application/javascript', 'text/html', JS2HTMLIMPORT

Sprockets.register_bundle_metadata_reducer 'text/css', :selector_count, :+

Sprockets.register_postprocessor 'text/css', proc { |input|
  { selector_count: input[:data].scan(/\{/).size }
}

SourceMapTransformer = proc { |input|
  accept = case input[:content_type]
  when "application/js-sourcemap+json"
    accept = "application/javascript"
  when "application/css-sourcemap+json"
    accept = "text/css"
  else
    fail input[:content_type]
  end

  uri, _ = input[:environment].resolve!(input[:filename], accept: accept)
  asset = input[:environment].load(uri)

  JSON.generate({
    "version" => 3,
    "file" => asset.logical_path,
    "mappings" => ";#{asset.bytesize}"
  })
}
Sprockets.register_mime_type 'application/js-sourcemap+json', extensions: ['.js.map']
Sprockets.register_mime_type 'application/css-sourcemap+json', extensions: ['.css.map']
Sprockets.register_transformer 'application/javascript', 'application/js-sourcemap+json', SourceMapTransformer
Sprockets.register_transformer 'text/css', 'application/css-sourcemap+json', SourceMapTransformer


class Sprockets::TestCase < MiniTest::Test
  FIXTURE_ROOT = File.expand_path(File.join(File.dirname(__FILE__), "fixtures"))

  def self.test(name, &block)
    define_method("test_#{name.inspect}", &block)
  end

  def fixture(path)
    IO.read(fixture_path(path))
  end

  def fixture_path(path)
    if path.match(FIXTURE_ROOT)
      path
    else
      File.join(FIXTURE_ROOT, path)
    end
  end

  def sandbox(*paths)
    backup_paths = paths.select { |path| File.exist?(path) }
    remove_paths = paths.select { |path| !File.exist?(path) }

    begin
      backup_paths.each do |path|
        FileUtils.cp(path, "#{path}.orig")
      end

      yield
    ensure
      backup_paths.each do |path|
        if File.exist?("#{path}.orig")
          FileUtils.mv("#{path}.orig", path)
        end

        assert !File.exist?("#{path}.orig")
      end

      remove_paths.each do |path|
        if File.exist?(path)
          FileUtils.rm_rf(path)
        end

        assert !File.exist?(path)
      end
    end
  end

  def write(filename, contents, mtime = nil)
    if File.exist?(filename)
      mtime ||= [Time.now.to_i, File.stat(filename).mtime.to_i].max + 1
      File.open(filename, 'w') do |f|
        f.write(contents)
      end
      File.utime(mtime, mtime, filename)
    else
      File.open(filename, 'w') do |f|
        f.write(contents)
      end
      File.utime(mtime, mtime, filename) if mtime
    end
  end
end
