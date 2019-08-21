lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vidar/version'

Gem::Specification.new do |spec|
  spec.name     = 'vidar'
  spec.version  = Vidar::VERSION
  spec.authors  = ['Krzysztof Knapik', 'RenoFi Engineering Team']
  spec.email    = ['knapo@knapo.net', 'engineering@renofi.com']

  spec.summary  = 'K8s deployment tools based on thor'
  spec.homepage = 'https://github.com/RenoFi/vidar'
  spec.license  = 'MIT'

  spec.metadata['homepage_uri'] = 'https://github.com/RenoFi/vidar'
  spec.metadata['source_code_uri'] = 'https://github.com/RenoFi/vidar'

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.4'

  spec.add_dependency 'colorize'
  spec.add_dependency 'thor', '~> 0.20'

  spec.add_development_dependency 'bundler', '~> 2.0'
  spec.add_development_dependency 'pry', '~> 0.12'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'rubocop', '~> 0.71'
end
