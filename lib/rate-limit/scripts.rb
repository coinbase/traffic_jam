require 'digest/sha1'

module RateLimit
  module Scripts
    def self.load(name)
      scripts_dir = File.join(File.dirname(__FILE__), '..', '..', 'scripts')
      File.read(File.join(scripts_dir, "#{name}.lua"))
    end
    private_class_method :load

    INCREMENT_SCRIPT = load('increment')
    INCREMENT_SCRIPT_HASH = Digest::SHA1.hexdigest(INCREMENT_SCRIPT)
  end
end
