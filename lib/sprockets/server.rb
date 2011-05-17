require 'rack/request'
require 'time'

module Sprockets
  # `Server` is a concern mixed into `Environment` and
  # `EnvironmentIndex` that provides a Rack compatible `call`
  # interface and url generation helpers.
  module Server
    # `call` implements the Rack 1.x specification which accepts an
    # `env` Hash and returns a three item tuple with the status code,
    # headers, and body.
    #
    # Mapping your environment at a url prefix will serve all assets
    # in the path.
    #
    #     map "/assets" do
    #       run Sprockets::Environment.new
    #     end
    #
    # A request for `"/assets/foo/bar.js"` will search your
    # environment for `"foo/bar.js"`.
    def call(env)
      # URLs containing a `".."` are rejected for security reasons.
      if forbidden_request?(env)
        return forbidden_response
      end

      # Mark session as "skipped" so no `Set-Cookie` header is set
      env['rack.session.options'] ||= {}
      env['rack.session.options'][:defer] = true
      env['rack.session.options'][:skip] = true

      # Lookup the asset by `PATH_INFO`
      asset = find_asset(env['PATH_INFO'].to_s.sub(/^\//, ''))

      # `find_asset` returns nil if the asset doesn't exist
      if asset.nil?
        # Return a 404 Not Found
        not_found_response

      # Check request headers `HTTP_IF_MODIFIED_SINCE` and
      # `HTTP_IF_NONE_MATCH` against the assets mtime and md5
      elsif not_modified?(asset, env) || etag_match?(asset, env)
        # Return a 403 Not Modified
        not_modified_response(asset, env)

      else
        # Return a 200 with the asset contents
        ok_response(asset, env)
      end
    end

    # `path` is a url helper that looks up an asset given a
    # `logical_path` and returns a path String. By default, the
    # asset's md5 fingerprint is spliced into the filename.
    #
    #     /assets/application-3676d55f84497cbeadfc614c1b1b62fc.js
    #
    # A third `prefix` argument can be pass along to be prepended to
    # the string.
    def path(logical_path, fingerprint = true, prefix = nil)
      if fingerprint && asset = find_asset(logical_path.to_s.sub(/^\//, ''))
        url = path_with_fingerprint(logical_path, asset.digest)
      else
        url = logical_path
      end

      url = File.join(prefix, url) if prefix
      url = "/#{url}" unless url =~ /^\//

      url
    end

    # Similar to `path`, `url` returns a full url given a Rack `env`
    # Hash and a `logical_path`.
    def url(env, logical_path, fingerprint = true, prefix = nil)
      req = Rack::Request.new(env)

      url = req.scheme + "://"
      url << req.host

      if req.scheme == "https" && req.port != 443 ||
          req.scheme == "http" && req.port != 80
        url << ":#{req.port}"
      end

      url << path(logical_path, fingerprint, prefix)

      url
    end

    private
      def forbidden_request?(env)
        # Prevent access to files elsewhere on the file system
        #
        #     http://example.org/assets/../../../etc/passwd
        #
        env["PATH_INFO"].include?("..")
      end

      # Returns a 403 Forbidden response tuple
      def forbidden_response
        [ 403, { "Content-Type" => "text/plain", "Content-Length" => "9" }, [ "Forbidden" ] ]
      end

      # Returns a 404 Not Found response tuple
      def not_found_response
        [ 404, { "Content-Type" => "text/plain", "Content-Length" => "9", "X-Cascade" => "pass" }, [ "Not found" ] ]
      end

      # Compare the requests `HTTP_IF_MODIFIED_SINCE` against the
      # assets mtime
      def not_modified?(asset, env)
        env["HTTP_IF_MODIFIED_SINCE"] == asset.mtime.httpdate
      end

      # Compare the requests `HTTP_IF_NONE_MATCH` against the assets MD5
      def etag_match?(asset, env)
        env["HTTP_IF_NONE_MATCH"] == etag(asset)
      end

      # Test if `?body=1` or `body=true` query param is set
      def body_only?(env)
        env["QUERY_STRING"].to_s =~ /body=(1|t)/
      end

      # Returns a 304 Not Modified response tuple
      def not_modified_response(asset, env)
        [ 304, {}, [] ]
      end

      # Returns a 200 OK response tuple
      def ok_response(asset, env)
        if body_only?(env) && asset.dependencies?
          body = asset.body
          [ 206, {
              "Content-Range"  => "bytes #{body.length-1}-#{asset.length-1}/#{asset.length}",
              "Content-Type"   => asset.content_type,
              "Content-Length" => body.length.to_s,
              "Cache-Control"  => "no-cache"
            }, [body] ]
        else
          [ 200, headers(asset, env), asset ]
        end
      end

      def headers(asset, env)
        Hash.new.tap do |headers|
          # Set content type and length headers
          headers["Content-Type"]   = asset.content_type
          headers["Content-Length"] = asset.length.to_s
          headers["Content-MD5"]    = asset.digest

          # Set caching headers
          headers["Cache-Control"]  = "public"
          headers["Last-Modified"]  = asset.mtime.httpdate
          headers["ETag"]           = etag(asset)

          # If the request url contains a fingerprint, set a long
          # expires on the response
          if path_fingerprint(env["PATH_INFO"])
            headers["Cache-Control"] << ", max-age=31536000"

          # Otherwise set `must-revalidate` since the could be modified.
          else
            headers["Cache-Control"] << ", must-revalidate"
          end
        end
      end

      # Helper to quote the assets MD5 for use as an ETag.
      def etag(asset)
        %("#{asset.digest}")
      end
  end
end
