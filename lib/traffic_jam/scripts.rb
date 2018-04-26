require 'digest/sha1'

module TrafficJam
  module Scripts
    def self.load(name)
      scripts_dir = File.join(File.dirname(__FILE__), '..', '..', 'scripts')
      File.read(File.join(scripts_dir, "#{name}.lua"))
    end
    private_class_method :load

    INCREMENT_SCRIPT = load('increment')
    INCREMENT_SCRIPT_HASH = Digest::SHA1.hexdigest(INCREMENT_SCRIPT)
    INCREMENT_SIMPLE = load('increment_simple')
    INCREMENT_SIMPLE_HASH = Digest::SHA1.hexdigest(INCREMENT_SIMPLE)
    INCREMENT_ROLLING = load('increment_rolling')
    INCREMENT_ROLLING_HASH = Digest::SHA1.hexdigest(INCREMENT_ROLLING)
    INCREMENT_GCRA = load('increment_gcra')
    INCREMENT_GCRA_HASH = Digest::SHA1.hexdigest(INCREMENT_GCRA)
    READ_GCRA = load('read_gcra')
    READ_GCRA_HASH = Digest::SHA1.hexdigest(READ_GCRA)
    INCRBY = load('incrby')
    INCRBY_HASH = Digest::SHA1.hexdigest(INCRBY)
    SUM_ROLLING = load('sum_rolling')
    SUM_ROLLING_HASH = Digest::SHA1.hexdigest(SUM_ROLLING)
  end
end
