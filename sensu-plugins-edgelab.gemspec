# frozen_string_literal: true

require 'date'

Gem::Specification.new do |s|
  s.authors                = ['Edgelab']
  s.description            = 'Sensu plugins developed by Edgelab'
  s.executables            = Dir.glob('bin/*.rb').map { |file| File.basename(file) }
  s.files                  = Dir.glob('bin/*')
  s.name                   = 'sensu-plugins-edgelab'
  s.platform               = Gem::Platform::RUBY
  s.required_ruby_version  = '>= 2.0.0'
  s.summary                = 'Contains Edgelab plugins for Sensu'

  s.version                = '1.18.1'

  s.add_runtime_dependency 'cassandra-driver',      '~> 3.2.2'
  s.add_runtime_dependency 'diplomat',              '2.0.2'
  s.add_runtime_dependency 'hipchat',               '1.5.1'
  s.add_runtime_dependency 'inifile',               '3.0.0'
  s.add_runtime_dependency 'redis',                 '3.2.1'
  s.add_runtime_dependency 'rest-client',           '1.8.0'
  s.add_runtime_dependency 'elasticsearch',         '~> 1.0.14'
  s.add_runtime_dependency 'sensu-plugin',          '~> 2.0'

  # Temporary until https://github.com/sensu-plugins/sensu-plugins-aws/pull/287
  # gets merged upstream and we can use a new version of sensu-plugins-aws.
  s.add_runtime_dependency 'aws-sdk',               '~> 3.0'
  s.add_runtime_dependency 'sensu-plugins-aws',     '~> 11.5.0'

  s.add_development_dependency 'bundler',           '~> 1.7'
  s.add_development_dependency 'rake',              '~> 10.5'
  s.add_development_dependency 'rubocop',           '~> 0.49.0'

  # postgres
  s.add_runtime_dependency 'pg', '0.18.4'
end
