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
  end
end
