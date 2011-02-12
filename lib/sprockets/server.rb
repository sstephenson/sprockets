require 'time'

module Sprockets
  class Server
    attr_accessor :environment

    def initialize(environment = Environment.new)
      self.environment = environment
      @extra_headers = {}
    end

    def call(env)
      environment.multithread = env["rack.multithread"]

      if forbidden_request?(env)
        return forbidden_response
      end

      asset = environment[env["PATH_INFO"]]

      if asset.nil?
        not_found_response
      elsif not_modified?(asset, env) || etag_match?(asset, env)
        not_modified_response(asset, env)
      elsif stale_query_string?(asset, env)
        gone_response(asset, env)
      else
        ok_response(asset, env)
      end
    end

    def extra_headers(headers)
      @extra_headers = headers
    end

    private
      def forbidden_request?(env)
        env["PATH_INFO"].include?("..")
      end

      def forbidden_response
        [ 403, { "Content-Type" => "text/plain", "Content-Length" => "9" }, [ "Forbidden" ] ]
      end

      def not_found_response
        [ 404, { "Content-Type" => "text/plain", "Content-Length" => "9" }, [ "Not found" ] ]
      end

      def not_modified?(asset, env)
        env["HTTP_IF_MODIFIED_SINCE"] == asset.mtime.httpdate
      end

      def etag_match?(asset, env)
        env["HTTP_IF_NONE_MATCH"] == etag(asset)
      end

      def stale_query_string?(asset, env)
        !env['QUERY_STRING'].nil? && !env['QUERY_STRING'].empty? &&
          env['QUERY_STRING'] != asset.digest
      end

      def not_modified_response(asset, env)
        [ 304, {}, [] ]
      end

      def gone_response(asset, env)
        [ 410, {}, [] ]
      end

      def ok_response(asset, env)
        [ 200, headers(asset, env), asset ]
      end

      def headers(asset, env)
        Hash.new.tap do |headers|
          headers["Content-Type"]   = asset.content_type
          headers["Content-Length"] = asset.length.to_s

          headers["Cache-Control"]  = "public, must-revalidate"
          headers["Last-Modified"]  = asset.mtime.httpdate
          headers["ETag"]           = etag(asset)

          if env["QUERY_STRING"] == asset.digest
            headers["Cache-Control"] << ", max-age=31557600"
          end
        end.merge(@extra_headers)
      end

      def etag(asset)
        %("#{asset.digest}")
      end
  end
end
