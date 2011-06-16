module Sprockets
  class Dependency
    attr_reader :environment_hexdigest
    attr_reader :path, :mtime, :hexdigest

    def self.from_path(environment, path)
      stat = environment.stat(path)
      raise ArgumentError unless stat
      new(environment.digest, path, stat.mtime, environment.file_digest(path))
    end

    def self.from_hash(hash)
      raise TypeError unless hash['class'] == 'Dependency'
      new(hash['environment_hexdigest'], hash['path'], hash['mtime'], hash['hexdigest'])
    end

    def initialize(environment_hexdigest, path, mtime, hexdigest)
      self.environment_hexdigest = environment_hexdigest
      self.path                  = path
      self.mtime                 = mtime
      self.hexdigest             = hexdigest
    end

    def init_with(coder)
      self.environment_hexdigest = coder['environment_hexdigest']
      self.path                  = coder['path']
      self.mtime                 = coder['mtime']
      self.hexdigest             = coder['hexdigest']
    end

    def encode_with(coder)
      coder['class']                 = 'Dependency'
      coder['environment_hexdigest'] = environment_hexdigest
      coder['path']                  = path
      coder['mtime']                 = mtime
      coder['hexdigest']             = hexdigest
    end

    def environment_hexdigest=(digest)
      if digest.respond_to?(:hexdigest)
        @environment_hexdigest = digest.hexdigest
      else
        @environment_hexdigest = digest
      end
    end

    def path=(path)
      @path = path.to_s
    end

    def mtime=(time)
      if time.is_a?(String)
        @mtime = Time.parse(time)
      else
        @mtime = time
      end
    end

    def hexdigest=(digest)
      if digest.respond_to?(:hexdigest)
        @hexdigest = digest.hexdigest
      else
        @hexdigest = digest
      end
    end

    def fresh?(environment)
      if environment.digest.hexdigest != environment_hexdigest
        return false
      end

      stat = environment.stat(path)

      if stat.nil?
        return false
      end

      if mtime >= stat.mtime
        return true
      end

      digest = environment.file_digest(path)

      if hexdigest == digest.hexdigest
        return true
      end

      false
    end

    def stale?(environment)
      !fresh?(environment)
    end
  end
end
