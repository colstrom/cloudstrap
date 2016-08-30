Gem::Specification.new do |gem|
  gem.name        = 'stackato-lkg'
  gem.version     = `git describe --tags --abbrev=0`.chomp + '.pre'
  gem.licenses    = 'MIT'
  gem.authors     = ['Chris Olstrom']
  gem.email       = 'chris@olstrom.com'
  gem.homepage    = 'https://github.com/colstrom/stackato-lkg'
  gem.summary     = 'Commandline Tool for bootstrapping Stackato 4.x from Last Known Good artifacts'

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  gem.require_paths = ['lib']

  gem.add_runtime_dependency 'aws-sdk', '~> 2.5', '>= 2.5.0'
  gem.add_runtime_dependency 'contracts', '~> 0.14', '>= 0.14.0'
  gem.add_runtime_dependency 'retries', '~> 0.0.5', '>= 0.0.5'
  gem.add_runtime_dependency 'moneta', '~> 0.8', '>= 0.8.0'
  gem.add_runtime_dependency 'sshkey', '~> 1.8', '>= 1.8.0'
  gem.add_runtime_dependency 'sshkit', '~> 1.11', '>= 1.11.0'
  gem.add_runtime_dependency 'java-properties', '~> 0.1', '>= 0.1.1'
  gem.add_runtime_dependency 'pastel', '~> 0.6', '>= 0.6.0'
end
