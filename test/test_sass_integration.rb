require 'sass'
require 'sprockets_test'
require 'tilt'
require 'yaml'

class TestSassIntegration < Sprockets::TestCase
  def setup
    @env = Sprockets::Environment.new
    @env.paths << fixture_path('sass')
  end

  test "Sass imports work" do
    assert_equal(<<CSS, render("application.css.scss"))
.partial-sass {
  color: green; }

.top-level {
  font-color: bold; }

.sub-folder-relative-scss {
  width: 250px; }

.partial-scss {
  color: blue; }

.sub-folder-relative-sass {
  width: 50px; }

.not-a-partial {
  border: 1px solid blue; }

.globbed-sass {
  color: blue; }

.globbed-scss {
  color: blue; }

.main {
  color: yellow;
  background-color: red; }
CSS
  end

  def scss_template(logical_path)
    Sprockets::ScssTemplate.new(resolve(logical_path).to_s)
  end

  def resolve(logical_path)
    @env.resolve(logical_path)
  end

  def read(logical_path)
    File.read(resolve(logical_path))
  end

  def render(logical_path)
    pathname = resolve(logical_path)
    scope = Sprockets::Context.new(@env, Sprockets::Concatenation.new(@env, pathname), pathname)
    scss_template(logical_path).render(scope)
  end
  
end