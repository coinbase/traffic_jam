#!/usr/bin/env ruby

require 'bundler/setup'
require 'rate-limit'
require 'json'
require 'redis'
require 'optparse'

options = {
  forks: 30,
  actions: 1000,
  keys: 5,
  limit: 100,
  redis_uri: 'redis://127.0.0.1:6379'
}

OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} <OPTIONS>"
  opts.on( "-f", "--forks FORKS", "How many processes to fork" ) { |i| options[:forks] = i.to_i }
  opts.on( "-n", "--actions N", "How many increments each process should perform" ) { |i| options[:actions] = i.to_i }
  opts.on( "-k", "--keys KEYS", "How many keys a process should run through" ) { |i| options[:keys] = i.to_i }
  opts.on( "-l", "--limit LIMIT", "Actions per second limit" ) { |i| options[:limit] = i.to_i }
  opts.on( "-u", "--redis-uri URI", "Redis URI" ) { |uri| options[:redis_uri] = uri }
  opts.on( "-h", "--help", "Display this usage summary" ) { puts opts; exit }
end.parse!

class Runner
  attr_accessor :options

  def initialize(options)
    @options = options
  end

  def run
    rate_limit = RateLimit.new(:test, options[:limit], 1)
    results = Hash[ (0...options[:keys]).map { |i| [ i, [ 0, 0 ] ] } ]
    options[:actions].times do
      i = results.keys.sample
      if rate_limit.increment("val#{i}")
        results[i][0] += 1
      else
        results[i][1] += 1
      end
    end
    results
  end

  def launch
    rd, wr = IO.pipe
    Kernel.fork do
      GC.copy_on_write_friendly = true if ( GC.copy_on_write_friendly? rescue false )
      rd.close

      RateLimit.config.redis = Redis.connect(url: options[:redis_uri])
      results = run

      wr.write(JSON.generate(results))
      wr.close
    end
    wr.close
    rd
  end
end

# main

puts "[#{Process.pid}] Starting with #{options.inspect}"

redis = Redis.connect(url: options[:redis_uri])
redis.flushall          # clean before run
redis.script(:flush)    # clean scripts before run
redis.client.disconnect # don't keep when forking

start = Time.now
pipes = options[:forks].times.map do
  Runner.new(options).launch
end
Process.waitall
elapsed = (Time.now - start).to_f

results = Hash[ (0...options[:keys]).map { |i| [ i, [ 0, 0 ] ] } ]
pipes.each do |pipe|
  proc_results = JSON.parse(pipe.read)
  pipe.close

  proc_results.each do |key, values|
    results[key.to_i][0] += values[0]
    results[key.to_i][1] += values[1]
  end
end

puts "TIME: %f seconds" % elapsed
results.each do |key, values|
  puts "KEY %-2d: Successes %-4d; Failures %-4d" % [key, values[0], values[1]]
end
