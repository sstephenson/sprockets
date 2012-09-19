require 'sprockets_test'
require 'fileutils'
require 'tmpdir'

class TestManifest < Sprockets::TestCase
  def setup
    @env = Sprockets::Environment.new(".") do |env|
      env.append_path(fixture_path('default'))
    end
    @dir = File.join(Dir::tmpdir, 'sprockets/manifest')
    @manifest = Sprockets::Manifest.new(@env, File.join(@dir, 'manifest.json'))
  end

  def teardown
    # FileUtils.rm_rf(@dir)
    # wtf, dunno
    system "rm -rf #{@dir}"
    assert Dir["#{@dir}/*"].empty?
  end

  test "specify full manifest path" do
    dir  = Dir::tmpdir
    path = File.join(dir, 'manifest.json')

    manifest = Sprockets::Manifest.new(@env, path)

    assert_equal dir, manifest.dir
    assert_equal path, manifest.path
  end

  test "specify full manifest directory" do
    dir  = Dir::tmpdir
    path = File.join(dir, 'manifest.json')

    manifest = Sprockets::Manifest.new(@env, dir)

    assert_equal dir, manifest.dir
    assert_equal path, manifest.path
  end

  test "compile asset" do
    digest_path = @env['application.js'].digest_path

    assert !File.exist?("#{@dir}/#{digest_path}")

    @manifest.compile('application.js')

    assert File.exist?("#{@dir}/manifest.json")
    assert File.exist?("#{@dir}/#{digest_path}")

    data = JSON.parse(File.read(@manifest.path))
    assert data['files'][digest_path]
    assert_equal "application.js", data['files'][digest_path]['logical_path']
    assert_equal 237, data['files'][digest_path]['size']
    assert_equal digest_path, data['assets']['application.js']
  end

  test "compile asset with absolute path" do
    digest_path = @env['application.js'].digest_path

    assert !File.exist?("#{@dir}/#{digest_path}")

    @manifest.compile(fixture_path('default/application.js.coffee'))

    assert File.exist?("#{@dir}/manifest.json")
    assert File.exist?("#{@dir}/#{digest_path}")

    data = JSON.parse(File.read(@manifest.path))
    assert data['files'][digest_path]
    assert_equal digest_path, data['assets']['application.js']
  end

  test "compile multiple assets" do
    app_digest_path = @env['application.js'].digest_path
    gallery_digest_path = @env['gallery.css'].digest_path

    assert !File.exist?("#{@dir}/#{app_digest_path}")
    assert !File.exist?("#{@dir}/#{gallery_digest_path}")

    @manifest.compile('application.js', 'gallery.css')

    assert File.exist?("#{@dir}/manifest.json")
    assert File.exist?("#{@dir}/#{app_digest_path}")
    assert File.exist?("#{@dir}/#{gallery_digest_path}")

    data = JSON.parse(File.read(@manifest.path))
    assert data['files'][app_digest_path]
    assert data['files'][gallery_digest_path]
    assert_equal app_digest_path, data['assets']['application.js']
    assert_equal gallery_digest_path, data['assets']['gallery.css']
  end

  test "compile with regex" do
    app_digest_path = @env['application.js'].digest_path
    gallery_digest_path = @env['gallery.css'].digest_path

    assert !File.exist?("#{@dir}/#{app_digest_path}")
    assert !File.exist?("#{@dir}/#{gallery_digest_path}")

    @manifest.compile('gallery.css', /application.js/)

    assert File.exist?("#{@dir}/manifest.json")
    assert File.exist?("#{@dir}/#{app_digest_path}")
    assert File.exist?("#{@dir}/#{gallery_digest_path}")

    data = JSON.parse(File.read(@manifest.path))
    assert data['files'][app_digest_path]
    assert data['files'][gallery_digest_path]
    assert_equal app_digest_path, data['assets']['application.js']
    assert_equal gallery_digest_path, data['assets']['gallery.css']
  end

  test "recompile asset" do
    digest_path = @env['application.js'].digest_path
    filename = fixture_path('default/application.js.coffee')

    sandbox filename do
      assert !File.exist?("#{@dir}/#{digest_path}"), Dir["#{@dir}/*"].inspect

      @manifest.compile('application.js')

      assert File.exist?("#{@dir}/manifest.json")
      assert File.exist?("#{@dir}/#{digest_path}")

      data = JSON.parse(File.read(@manifest.path))
      assert data['files'][digest_path]
      assert_equal digest_path, data['assets']['application.js']

      File.open(filename, 'w') { |f| f.write "change;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, filename)
      new_digest_path = @env['application.js'].digest_path

      @manifest.compile('application.js')

      assert File.exist?("#{@dir}/manifest.json")
      assert File.exist?("#{@dir}/#{digest_path}")
      assert File.exist?("#{@dir}/#{new_digest_path}")

      data = JSON.parse(File.read(@manifest.path))
      assert data['files'][digest_path]
      assert data['files'][new_digest_path]
      assert_equal new_digest_path, data['assets']['application.js']
    end
  end

  test "remove asset" do
    digest_path = @env['application.js'].digest_path

    @manifest.compile('application.js')
    assert File.exist?("#{@dir}/#{digest_path}")

    data = JSON.parse(File.read(@manifest.path))
    assert data['files'][digest_path]
    assert data['assets']['application.js']

    @manifest.remove(digest_path)

    assert !File.exist?("#{@dir}/#{digest_path}")

    data = JSON.parse(File.read(@manifest.path))
    assert !data['files'][digest_path]
    assert !data['assets']['application.js']
  end

  test "remove old asset" do
    digest_path = @env['application.js'].digest_path
    filename = fixture_path('default/application.js.coffee')

    sandbox filename do
      @manifest.compile('application.js')
      assert File.exist?("#{@dir}/#{digest_path}")

      File.open(filename, 'w') { |f| f.write "change;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, filename)
      new_digest_path = @env['application.js'].digest_path

      @manifest.compile('application.js')
      assert File.exist?("#{@dir}/#{new_digest_path}")

      @manifest.remove(digest_path)
      assert !File.exist?("#{@dir}/#{digest_path}")

      data = JSON.parse(File.read(@manifest.path))
      assert !data['files'][digest_path]
      assert data['files'][new_digest_path]
      assert_equal new_digest_path, data['assets']['application.js']
    end
  end

  test "remove old backups" do
    digest_path = @env['application.js'].digest_path
    filename = fixture_path('default/application.js.coffee')

    sandbox filename do
      @manifest.compile('application.js')
      assert File.exist?("#{@dir}/#{digest_path}")

      File.open(filename, 'w') { |f| f.write "a;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, filename)
      new_digest_path1 = @env['application.js'].digest_path

      @manifest.compile('application.js')
      assert File.exist?("#{@dir}/#{new_digest_path1}")

      File.open(filename, 'w') { |f| f.write "b;" }
      mtime = Time.now + 2
      File.utime(mtime, mtime, filename)
      new_digest_path2 = @env['application.js'].digest_path

      @manifest.compile('application.js')
      assert File.exist?("#{@dir}/#{new_digest_path2}")

      File.open(filename, 'w') { |f| f.write "c;" }
      mtime = Time.now + 3
      File.utime(mtime, mtime, filename)
      new_digest_path3 = @env['application.js'].digest_path

      @manifest.compile('application.js')
      assert File.exist?("#{@dir}/#{new_digest_path3}")

      @manifest.clean(1)

      assert !File.exist?("#{@dir}/#{digest_path}")
      assert !File.exist?("#{@dir}/#{new_digest_path1}")
      assert File.exist?("#{@dir}/#{new_digest_path2}")
      assert File.exist?("#{@dir}/#{new_digest_path3}")

      data = JSON.parse(File.read(@manifest.path))
      assert !data['files'][digest_path]
      assert !data['files'][new_digest_path1]
      assert data['files'][new_digest_path2]
      assert data['files'][new_digest_path3]
      assert_equal new_digest_path3, data['assets']['application.js']
    end
  end

  test "test manifest does not exist" do
    assert !File.exist?("#{@dir}/manifest.json")

    @manifest = Sprockets::Manifest.new(@env, File.join(@dir, 'manifest.json'))
    @manifest.compile('application.js')

    assert File.exist?("#{@dir}/manifest.json")
    data = JSON.parse(File.read(@manifest.path))
    assert data['assets']['application.js']
  end

  test "test blank manifest" do
    assert !File.exist?("#{@dir}/manifest.json")

    FileUtils.mkdir_p(@dir)
    File.open("#{@dir}/manifest.json", 'w') { |f| f.write "" }
    assert_equal "", File.read("#{@dir}/manifest.json")

    @manifest = Sprockets::Manifest.new(@env, File.join(@dir, 'manifest.json'))
    @manifest.compile('application.js')

    assert File.exist?("#{@dir}/manifest.json")
    data = JSON.parse(File.read(@manifest.path))
    assert data['assets']['application.js']
  end

  test "test skip invalid manifest" do
    assert !File.exist?("#{@dir}/manifest.json")

    FileUtils.mkdir_p(@dir)
    File.open("#{@dir}/manifest.json", 'w') { |f| f.write "not valid json;" }
    assert_equal "not valid json;", File.read("#{@dir}/manifest.json")

    @manifest = Sprockets::Manifest.new(@env, File.join(@dir, 'manifest.json'))
    @manifest.compile('application.js')

    assert File.exist?("#{@dir}/manifest.json")
    data = JSON.parse(File.read(@manifest.path))
    assert data['assets']['application.js']
  end
end
