require "sprockets_test"
require "yaml"

class TestCompiler < Sprockets::TestCase
  test "options get saved" do
    sprockets_file = fixture_path('cli/' + Sprockets::CLI::SPROCKETS_FILE)
    args = [
      '-a', fixture_path('cli'),
      '-I', fixture_path('server/app/javascripts'),
      '-I', fixture_path('compiler'),
      '-j', 'closure',
      '-c',
      '-d',
      '-g',
      '-m', fixture_path('.'),
      '-s',
      'compiled',
      'cli1.js',
      'cli2.js'
    ]

    files = [
        fixture_path('manifest.yml'),
        sprockets_file,
        fixture_path('cli/compiled')
    ]

    sandbox(*files) do
      cli = Sprockets::CLI.new(*args)
      cli.run

      assert File.exists?(sprockets_file)

      options = YAML.load(File.open(sprockets_file))

      assert_equal 2, options['paths'].length
      assert options['paths'].include?(fixture_path('server/app/javascripts'))
      assert options['paths'].include?(fixture_path('compiler'))
      assert_equal :closure, options['js_compressor']
      assert options['compress_css']
      assert options['digest']
      assert options['gzip']
      assert options['manifest']
      assert_equal fixture_path('.'), options['manifest_path']
      assert_equal 'compiled', options['target']
      assert_equal 2, options['assets'].length
      assert options['assets'].include?('cli1.js')
      assert options['assets'].include?('cli2.js')
    end
  end

  test "only given assets get compiled" do
    args = [
      '-a', fixture_path('cli'),
      'compiled',
      'cli1.js'
    ]

    compiled_path = fixture_path('cli/compiled')

    sandbox compiled_path do
      cli = Sprockets::CLI.new(*args)
      cli.run

      assert File.exists?(File.join(compiled_path, 'cli1.js'))
      assert !File.exists?(File.join(compiled_path, 'cli2.js'))
    end
  end

  test "local options file is loaded" do
    args = [
      '-a', fixture_path('cli/sprockets_file')
    ]

    cli = Sprockets::CLI.new(*args)

    assert cli.local_options[:assets].include?('cli_sprockets.js')
    assert_equal '../compiled', cli.local_options[:target]
  end

  test "global options file is loaded" do
    args = [
      '-a', fixture_path('cli/sprockets_file')
    ]

    global_file = File.join(ENV['HOME'], Sprockets::CLI::SPROCKETS_FILE)
    sandbox global_file do
      File.open(global_file, 'wb') do |f|
        YAML.dump({:paths => '/global/path'}, f)
      end

      cli = Sprockets::CLI.new(*args)

      assert cli.global_options[:paths].include?('/global/path')
    end
  end
end