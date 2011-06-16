module Sprockets
  module Digest
    def digest_class
      @digest_class
    end

    def digest_class=(klass)
      expire_index!
      @digest_class = klass
    end

    def digest_key_prefix
      @digest_key_prefix
    end

    def digest_key_prefix=(prefix)
      expire_index!
      @digest_key_prefix = prefix
    end

    def digest
      @digest ||= compute_digest
      @digest.dup
    end

    protected
      def compute_digest
        digest_class.new.update(VERSION).update(digest_key_prefix.to_s)
      end
  end
end
