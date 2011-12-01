require 'fileutils'

module Sprockets
  class Compiler
    attr_accessor :env, :target, :paths

    def initialize(env, target, paths, options = {})
      @env = env
      @target = target
      @paths = paths
      @gzip = options.key?(:gzip) ? options.delete(:gzip) : false
      @digest = options.key?(:digest) ? options.delete(:digest) : false
      @manifest = options.key?(:manifest) ? options.delete(:manifest) : false
      @manifest_path = options.delete(:manifest_path) || target
    end

    def compile
      manifest = {}
      env.each_logical_path do |logical_path|
        asset = env.find_asset(logical_path)
        next if asset.nil? || !compile_asset?(asset)
        manifest[logical_path] = write_asset(asset)
      end
      write_manifest(manifest) if @manifest
    end

    def write_manifest(manifest)
      FileUtils.mkdir_p(@manifest_path)
      File.open("#{@manifest_path}/manifest.yml", 'wb') do |f|
        YAML.dump(manifest, f)
      end
    end

    def write_asset(asset)
      path_for(asset).tap do |path|
        filename = File.join(target, path)
        FileUtils.mkdir_p File.dirname(filename)
        asset.write_to(filename)
        asset.write_to("#{filename}.gz") if @gzip && filename.to_s =~ /\.(css|js)$/
      end
    end

    def compile_asset?(asset)
      paths.each do |path|
        case path
        when Regexp
          return true if path.match(asset)
        when Proc
          return true if path.call(asset)
        else
          return true if File.fnmatch(path.to_s, asset.pathname.to_s)
        end
      end
      false
    end

    def path_for(asset)
      @digest ? asset.digest_path : asset.logical_path
    end
  end
end
