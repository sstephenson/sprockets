require 'sprockets/asset'
require 'sprockets/digest_utils'
require 'sprockets/errors'
require 'sprockets/file_reader'
require 'sprockets/mime'
require 'sprockets/path_utils'
require 'sprockets/processing'
require 'sprockets/processor_utils'
require 'sprockets/resolve'
require 'sprockets/transformers'
require 'sprockets/uri_utils'

module Sprockets
  # The loader phase takes a asset URI location and returns a constructed Asset
  # object.
  module Loader
    include DigestUtils, PathUtils, ProcessorUtils, URIUtils
    include Mime, Processing, Resolve, Transformers

    # Public: Load Asset by AssetURI.
    #
    # uri - AssetURI
    #
    # Returns Asset.
    def load(uri)
      filename, params = parse_asset_uri(uri)
      if params.key?(:id)
        asset = cache.fetch(['asset-uri', uri]) do
          load_asset_by_id_uri(uri, filename, params)
        end
      else
        asset = fetch_asset_from_dependency_cache(uri, filename) do |paths|
          if paths
            digest = digest(resolve_dependencies(paths))
            if id_uri = cache.get(['asset-uri-digest', VERSION, uri, digest], true)
              cache.get(['asset-uri', VERSION, id_uri], true)
            end
          else
            load_asset_by_uri(uri, filename, params)
          end
        end
      end
      Asset.new(asset)
    end

    private
      def load_asset_by_id_uri(uri, filename, params)
        # Internal assertion, should be routed through load_asset_by_uri
        unless id = params.delete(:id)
          raise ArgumentError, "expected uri to have an id: #{uri}"
        end

        uri = build_asset_uri(filename, params)
        asset = load_asset_by_uri(uri, filename, params)

        if id && asset[:id] != id
          raise VersionNotFound, "could not find specified id: #{id}"
        end

        asset
      end

      def load_asset_by_uri(uri, filename, params)
        # Internal assertion, should be routed through load_asset_by_id_uri
        if params.key?(:id)
          raise ArgumentError, "expected uri to have no id: #{uri}"
        end

        unless file?(filename)
          raise FileNotFound, "could not find file: #{filename}"
        end

        load_path, logical_path = paths_split(config[:paths], filename)

        unless load_path
          raise FileOutsidePaths, "#{filename} is no longer under a load path: #{self.paths.join(', ')}"
        end

        full_logical_path = logical_path
        extname, file_type = match_path_extname(logical_path, mime_exts)
        logical_path = logical_path.chomp(extname)
        logical_path = normalize_logical_path(logical_path)
        name = logical_path

        if type = params[:type]
          logical_path += config[:mime_types][type][:extensions].first
        end

        if type != file_type && !config[:transformers][file_type][type]
          raise ConversionError, "could not convert #{file_type.inspect} to #{type.inspect}"
        end

        skip_bundle = params[:skip_bundle]
        processors = processors_for(type, file_type, skip_bundle)

        processors_dep_uri = build_processors_uri(type, file_type, skip_bundle)
        dependencies = config[:dependencies] + [processors_dep_uri]

        # Read into memory and process if theres a processor pipeline
        if processors.any?
          source_path = full_logical_path # TODO: Use foo.source.js
          result = call_processors(processors, {
            environment: self,
            cache: self.cache,
            uri: uri,
            filename: filename,
            load_path: load_path,
            source_path: source_path,
            name: name,
            content_type: type,
            metadata: {
              dependencies: dependencies,
              map: SourceMap::Map.new([
                SourceMap::Mapping.new(
                  source_path,
                  SourceMap::Offset.new(0, 0),
                  SourceMap::Offset.new(0, 0)
                )
              ], logical_path)
            }
          })
          source = result.delete(:data)
          metadata = result.merge!(
            charset: source.encoding.name.downcase,
            digest: digest(source),
            length: source.bytesize
          )
        else
          metadata = {
            digest: file_digest(filename),
            length: self.stat(filename).size,
            dependencies: dependencies
          }
        end

        asset = {
          uri: uri,
          load_path: load_path,
          filename: filename,
          name: name,
          logical_path: logical_path,
          content_type: type,
          source: source,
          metadata: metadata,
          integrity: integrity_uri(metadata[:digest], type),
          dependencies_digest: digest(resolve_dependencies(metadata[:dependencies]))
        }

        asset[:id]  = pack_hexdigest(digest(asset))
        asset[:uri] = build_asset_uri(filename, params.merge(id: asset[:id]))

        cache.set(['asset-uri', VERSION, asset[:uri]], asset, true)
        cache.set(['asset-uri-digest', VERSION, uri, asset[:dependencies_digest]], asset[:uri], true)

        asset
      end

      def fetch_asset_from_dependency_cache(uri, filename, limit = 3)
        key = ['asset-uri-cache-dependencies', VERSION, uri, file_digest(filename)]
        history = cache.get(key) || []

        history.each_with_index do |deps, index|
          if asset = yield(deps)
            cache.set(key, history.rotate!(index)) if index > 0
            return asset
          end
        end

        asset = yield
        deps = asset[:metadata][:dependencies]
        cache.set(key, history.unshift(deps).take(limit))
        asset
      end
  end
end
