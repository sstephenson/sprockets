module Sprockets
  # `Fingerprinting` is an internal mixin whose public methods are exposed on
  # the `Environment` and `Index` classes.
  module Fingerprinting
    # Checks if asset path fingerprinting is enabled.
    def fingerprinting_enabled?
      @fingerprinting_enabled
    end

    # Enable or disable asset path fingerprinting.
    def fingerprinting_enabled=(enabled)
      @fingerprinting_enabled = enabled
    end

    # Returns an `Array` of paths, globs or `Regexp`s that
    # should be excluded from asset path fingerprinting.
    def fingerprinting_exclusions
      @fingerprinting_exclusions ||= []
    end

    # Set the paths that should be excluded from asset path fingerprinting.
    def fingerprinting_exclusions=(exclusions)
      @fingerprinting_exclusions = exclusions
    end

    # Checks if the path should be fingerprinted.
    def fingerprint_path?(logical_path)
      fingerprinting_enabled? && !exclude_path_from_fingerprinting?(logical_path)
    end

    private
      # Checks if the given path is in the current list
      # of fingerprinting exclusions.
      def exclude_path_from_fingerprinting?(logical_path)
        fingerprinting_exclusions.any? do |path|
          if path.is_a?(Regexp)
            # Match path against `Regexp`
            path.match(logical_path)
          else
            # Otherwise use fnmatch glob syntax
            File.fnmatch(path.to_s, logical_path)
          end
        end
      end
  end
end
