Gem::Specification.new do |s|
  s.name        = "traffic_jam"
  s.version     = "1.0.0"
  s.licenses    = ["MIT"]
  s.summary     = "Library for time-based rate limiting"
  s.description = "Library for Redis-backed time-based rate limiting"
  s.authors     = ["Jim Posen"]
  s.email       = "jimpo@coinbase.com"
  s.files       = Dir.glob("lib/**/*.rb") + Dir.glob("scripts/**/*.lua")
  s.homepage    = ""

  s.add_dependency 'redis', '~> 3.0'
  s.add_development_dependency 'rake', '~> 10.0'
end
