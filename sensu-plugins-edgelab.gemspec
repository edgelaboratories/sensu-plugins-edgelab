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
  s.version                = '1.5.1'

  s.add_runtime_dependency 'sensu-plugin', '~> 1.2'
  s.add_runtime_dependency 'diplomat',     '0.14.0'
  s.add_runtime_dependency 'inifile', '3.0.0'
  s.add_runtime_dependency 'rest-client', '1.8.0'
  s.add_runtime_dependency 'ruby-mysql', '~> 2.9'

  s.add_runtime_dependency 'sensu-plugins-aws', '4.0.0'

  s.add_development_dependency 'bundler',                   '~> 1.7'
  s.add_development_dependency 'rake',                      '~> 10.5'
  s.add_development_dependency 'rubocop',                   '~> 0.40.0'
end
