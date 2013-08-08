$:.unshift File.expand_path("../lib", __FILE__)
require "sprockets/version"

Gem::Specification.new do |s|
  s.name = "sprockets"
  s.version = Sprockets::VERSION
  s.summary = "Rack-based asset packaging system"
  s.description = "Sprockets is a Rack-based asset packaging system that concatenates and serves JavaScript, CoffeeScript, CSS, LESS, Sass, and SCSS."
  s.license = "MIT"

  s.files = Dir["README.md", "LICENSE", "lib/**/*.rb"]
  s.executables = ["sprockets"]

  s.add_dependency "hike", "~> 1.2"
  s.add_dependency "multi_json", "~> 1.0"
  s.add_dependency "rack", "~> 1.0"
  s.add_dependency "tilt", ["~> 1.1", "!= 1.3.0"]

  s.add_development_dependency "closure-compiler"
  s.add_development_dependency "coffee-script", "~> 2.0"
  s.add_development_dependency "coffee-script-source", "~> 1.2"
  s.add_development_dependency "eco", "~> 1.0"
  s.add_development_dependency "ejs", "~> 1.0"
  s.add_development_dependency "execjs", "~> 1.0"
  s.add_development_dependency "json"
  s.add_development_dependency "rack-test"
  s.add_development_dependency "rake"
  s.add_development_dependency "sass", "~> 3.1"
  s.add_development_dependency "uglifier"
  s.add_development_dependency "yui-compressor"

  s.authors = ["Sam Stephenson", "Joshua Peek"]
  s.email = ["sstephenson@gmail.com", "josh@joshpeek.com"]
  s.homepage = "http://getsprockets.org/"
  s.rubyforge_project = "sprockets"

  s.required_ruby_version = '>= 1.9.3'
end
