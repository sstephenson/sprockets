require "sprockets_test"

class TestCompiler < Sprockets::TestCase
  def setup
    @target = fixture_path('compiler/compiled')
    @env = Sprockets::Environment.new(fixture_path('compiler'))
    @env.append_path('.')
    @env.append_path(fixture_path('server/app/javascripts'))
  end

  test "only allowed assets get compiled" do
    paths = [
      /file1\.js/,
      Proc.new {|a| a.pathname.to_s.end_with?('file2.js')},
      fixture_path('compiler/file3.js')
    ]

    compiler = Sprockets::Compiler.new(@env, @target, paths, {})

    sandbox @target do
      compiler.compile

      assert File.exists?(File.join(@target, 'file1.js'))
      assert File.exists?(File.join(@target, 'file2.js'))
      assert File.exists?(File.join(@target, 'file3.js'))
      assert !File.exists?(File.join(@target, 'file4.js'))
    end
  end

  test "manifest gets written" do
    paths = [/file1\.js/]
    compiler = Sprockets::Compiler.new(@env, @target, paths, {:manifest => true})

    sandbox @target do
      compiler.compile

      assert File.exists?(File.join(@target, 'manifest.yml'))
    end
  end

  test "files get compressed" do
    paths = [/file1\.js/]
    compiler = Sprockets::Compiler.new(@env, @target, paths, {:gzip => true})

    sandbox @target do
      compiler.compile

      assert File.exists?(File.join(@target, 'file1.js.gz'))
    end
  end

  test "digest hash gets added to file names" do
    paths = [/file1\.js/]
    compiler1 = Sprockets::Compiler.new(@env, @target, paths, {:digest => true})
    compiler2 = Sprockets::Compiler.new(@env, @target, paths, {:digest => false})
    asset = @env.find_asset('file1.js')
    path1 = compiler1.path_for(asset)
    path2 = compiler2.path_for(asset)

    assert path1 != 'file1.js'
    assert path1.start_with?('file1-')
    assert path2 == 'file1.js'
  end
end