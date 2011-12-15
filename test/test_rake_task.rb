require 'sprockets_test'

require 'rake/sprocketstask'
require 'rake'

class TestRakeTask < Sprockets::TestCase
  def setup
    @rake = Rake::Application.new
    Rake.application = @rake

    @env = Sprockets::Environment.new(".") do |env|
      env.append_path(fixture_path('default'))
    end

    @dir = File.join(Dir::tmpdir, 'sprockets/manifest')

    Rake::SprocketsTask.new do |t|
      t.environment = @env
      t.output      = @dir
      t.assets      = ['application.js']
      t.log_level   = :fatal
    end
  end

  def teardown
    Rake.application = nil

    # FileUtils.rm_rf(@dir)
    # wtf, dunno
    system "rm -rf #{@dir}"
    assert Dir["#{@dir}/*"].empty?
  end

  test "assets" do
    assert !File.exist?("#{@dir}/application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js")

    @rake[:assets].invoke

    assert File.exist?("#{@dir}/manifest.json")
    assert File.exist?("#{@dir}/application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js")
  end

  test "clobber" do
    @rake[:assets].invoke
    assert File.exist?("#{@dir}/application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js")

    @rake[:clobber_assets].invoke
    assert !File.exist?("#{@dir}/application-2e8e9a7c6b0aafa0c9bdeec90ea30213.js")
  end
end
