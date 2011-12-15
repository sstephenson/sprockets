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
    assert !File.exist?("#{@dir}/application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js")

    @manifest.compile('application.js')

    assert File.exist?("#{@dir}/manifest.json")
    assert File.exist?("#{@dir}/application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js")

    data = JSON.parse(File.read(@manifest.path))
    assert data['files']['application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js']
    assert_equal 'application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js',
      data['assets']['application.js']
  end

  test "compile multiple assets" do
    assert !File.exist?("#{@dir}/application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js")
    assert !File.exist?("#{@dir}/gallery-5d6e8915d9fd22fbb04afd4a99a57ce4.css")

    @manifest.compile('application.js', 'gallery.css')

    assert File.exist?("#{@dir}/manifest.json")
    assert File.exist?("#{@dir}/application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js")
    assert File.exist?("#{@dir}/gallery-5d6e8915d9fd22fbb04afd4a99a57ce4.css")

    data = JSON.parse(File.read(@manifest.path))
    assert data['files']['application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js']
    assert data['files']['gallery-5d6e8915d9fd22fbb04afd4a99a57ce4.css']
    assert_equal 'application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js',
      data['assets']['application.js']
    assert_equal 'gallery-5d6e8915d9fd22fbb04afd4a99a57ce4.css',
      data['assets']['gallery.css']
  end

  test "recompile asset" do
    filename = fixture_path('default/application.js.coffee')

    sandbox filename do
      assert !File.exist?("#{@dir}/application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js"), Dir["#{@dir}/*"].inspect

      @manifest.compile('application.js')

      assert File.exist?("#{@dir}/manifest.json")
      assert File.exist?("#{@dir}/application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js")

      data = JSON.parse(File.read(@manifest.path))
      assert data['files']['application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js']
      assert_equal 'application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js',
        data['assets']['application.js']

      File.open(filename, 'w') { |f| f.write "change;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, filename)

      @manifest.compile('application.js')

      assert File.exist?("#{@dir}/manifest.json")
      assert File.exist?("#{@dir}/application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js")
      assert File.exist?("#{@dir}/application-fd3c12c6a14c82fc6d487f25c5f54f91.js")

      data = JSON.parse(File.read(@manifest.path))
      assert data['files']['application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js']
      assert data['files']['application-fd3c12c6a14c82fc6d487f25c5f54f91.js']
      assert_equal 'application-fd3c12c6a14c82fc6d487f25c5f54f91.js',
        data['assets']['application.js']
    end
  end

  test "remove asset" do
    @manifest.compile('application.js')
    assert File.exist?("#{@dir}/application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js")

    data = JSON.parse(File.read(@manifest.path))
    assert data['files']['application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js']
    assert data['assets']['application.js']

    @manifest.remove('application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js')

    assert !File.exist?("#{@dir}/application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js")

    data = JSON.parse(File.read(@manifest.path))
    assert !data['files']['application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js']
    assert !data['assets']['application.js']
  end

  test "remove old asset" do
    filename = fixture_path('default/application.js.coffee')

    sandbox filename do
      @manifest.compile('application.js')
      assert File.exist?("#{@dir}/application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js")

      File.open(filename, 'w') { |f| f.write "change;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, filename)

      @manifest.compile('application.js')
      assert File.exist?("#{@dir}/application-fd3c12c6a14c82fc6d487f25c5f54f91.js")

      @manifest.remove('application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js')
      assert !File.exist?("#{@dir}/application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js")

      data = JSON.parse(File.read(@manifest.path))
      assert !data['files']['application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js']
      assert data['files']['application-fd3c12c6a14c82fc6d487f25c5f54f91.js']
      assert_equal 'application-fd3c12c6a14c82fc6d487f25c5f54f91.js',
        data['assets']['application.js']
    end
  end

  test "remove old backups" do
    filename = fixture_path('default/application.js.coffee')

    sandbox filename do
      @manifest.compile('application.js')
      assert File.exist?("#{@dir}/application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js")

      File.open(filename, 'w') { |f| f.write "a;" }
      mtime = Time.now + 1
      File.utime(mtime, mtime, filename)

      @manifest.compile('application.js')
      assert File.exist?("#{@dir}/application-ae0908555a245f8266f77df5a8edca2e.js")

      File.open(filename, 'w') { |f| f.write "b;" }
      mtime = Time.now + 2
      File.utime(mtime, mtime, filename)

      @manifest.compile('application.js')
      assert File.exist?("#{@dir}/application-226d144e6d700f802aafe2cbcc16f8dc.js")

      File.open(filename, 'w') { |f| f.write "c;" }
      mtime = Time.now + 3
      File.utime(mtime, mtime, filename)

      @manifest.compile('application.js')
      assert File.exist?("#{@dir}/application-019a310ae5bf296ee17beda7886a27b3.js")

      @manifest.clean(1)

      assert !File.exist?("#{@dir}/application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js")
      assert !File.exist?("#{@dir}/application-ae0908555a245f8266f77df5a8edca2e.js")
      assert File.exist?("#{@dir}/application-226d144e6d700f802aafe2cbcc16f8dc.js")
      assert File.exist?("#{@dir}/application-019a310ae5bf296ee17beda7886a27b3.js")

      data = JSON.parse(File.read(@manifest.path))
      assert !data['files']['application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js']
      assert !data['files']['application-ae0908555a245f8266f77df5a8edca2e.js']
      assert data['files']['application-226d144e6d700f802aafe2cbcc16f8dc.js']
      assert data['files']['application-019a310ae5bf296ee17beda7886a27b3.js']
      assert_equal 'application-019a310ae5bf296ee17beda7886a27b3.js',
        data['assets']['application.js']
    end
  end
end
