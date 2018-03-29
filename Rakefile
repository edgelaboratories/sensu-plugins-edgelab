# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rubocop/rake_task'

args = %i[make_bin_executable rubocop check_binstubs]

RuboCop::RakeTask.new

desc 'Make all plugins executable'
task :make_bin_executable do
  `chmod -R +x bin/*`
end

desc 'Test for binstubs'
task :check_binstubs do
  bin_list = Gem::Specification.load('sensu-plugins-edgelab.gemspec').executables
  bin_list.each do |b|
    `which #{ b }`
    unless $CHILD_STATUS.success?
      puts "#{b} was not a binstub"
      exit
    end
  end
end

task default: args
