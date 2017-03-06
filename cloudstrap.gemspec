Gem::Specification.new do |gem|
  gem.name        = 'cloudstrap'
  gem.version     = `git describe --tags --abbrev=0`.chomp + '.pre'
  gem.licenses    = 'MIT'
  gem.authors     = ['Chris Olstrom']
  gem.email       = 'chris@olstrom.com'
  gem.homepage    = 'https://github.com/colstrom/cloudstrap'
  gem.summary     = 'Strapping Boots to Clouds'

  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  gem.require_paths = ['lib']

  gem.add_runtime_dependency 'aws-sdk', '~> 2.7', '>= 2.7.0'
  gem.add_runtime_dependency 'burdened-acrobat', '~> 0.3', '>= 0.3.4'
  gem.add_runtime_dependency 'concurrent-ruby', '~> 1.0', '>= 1.0.0'
  gem.add_runtime_dependency 'contracts', '~> 0.14', '>= 0.14.0', '<= 0.15.0'
  gem.add_runtime_dependency 'faraday', '~> 0.11', '>= 0.11.0'
  gem.add_runtime_dependency 'ipaddress', '~> 0.8', '>= 0.8.0'
  gem.add_runtime_dependency 'java-properties', '~> 0.2', '>= 0.2.0'
  gem.add_runtime_dependency 'moneta', '~> 0.8', '>= 0.8.0'
  gem.add_runtime_dependency 'multi_json', '~> 1.12', '>= 1.12.0'
  gem.add_runtime_dependency 'path53', '~> 0.4', '>= 0.4.8'
  gem.add_runtime_dependency 'retries', '~> 0.0.5', '>= 0.0.5'
  gem.add_runtime_dependency 'sshkey', '~> 1.9', '>= 1.9.0'
  gem.add_runtime_dependency 'sshkit', '~> 1.12', '>= 1.12.0'
  gem.add_runtime_dependency 'tty-spinner', '~> 0.4', '>= 0.4.0'
  gem.add_runtime_dependency 'tty-table', '~> 0.8', '>= 0.8.0'

  gem.add_runtime_dependency 'pastel', '~> 0.7', '>= 0.7.0'
end
