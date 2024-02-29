lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'vidar/version'

Gem::Specification.new do |spec|
  spec.name = 'vidar'
  spec.version = Vidar::VERSION
  spec.authors = ['Krzysztof Knapik', 'RenoFi Engineering Team']
  spec.email = ['knapo@knapo.net', 'engineering@renofi.com']

  spec.summary = 'K8s deployment tools based on thor'
  spec.homepage = 'https://github.com/RenoFi/vidar'
  spec.license = 'MIT'

  spec.metadata['homepage_uri'] = 'https://github.com/RenoFi/vidar'
  spec.metadata['source_code_uri'] = 'https://github.com/RenoFi/vidar'
  spec.metadata['changelog_uri'] = 'https://github.com/RenoFi/vidar/blob/master/CHANGELOG.md'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.required_ruby_version = Gem::Requirement.new('>= 3.1.0')

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(bin/|spec/|\.rub)}) }
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'colorize'
  spec.add_dependency 'faraday'
  spec.add_dependency 'thor', '~> 1.0'
end
