require "test/unit"
require "sprockets"
require "tilt"
require "fileutils"

if defined? Encoding
  old_verbose, $VERBOSE = $VERBOSE, false
  Encoding.default_external = 'UTF-8'
  Encoding.default_internal = 'UTF-8'
  $VERBOSE = old_verbose
end

class Sprockets::TestCase < Test::Unit::TestCase
  FIXTURE_ROOT = File.expand_path(File.join(File.dirname(__FILE__), "fixtures"))

  undef_method :default_test if method_defined? :default_test

  def self.test(name, &block)
    define_method("test #{name.inspect}", &block)
  end

  def fixture(path)
    IO.read(fixture_path(path))
  end

  def fixture_path(path)
    File.join(FIXTURE_ROOT, path)
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
end
