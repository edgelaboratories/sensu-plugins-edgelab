#! /usr/bin/env ruby
#
#   check-consul-services
#
# DESCRIPTION:
#   Check the status of the services registered in Consul.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: diplomat
#
# USAGE:
#   ./check-consul-services
#
# NOTES:
#
# LICENSE:
#   Copyright 2017 Jonathan Ballet <jballet@edgelab.ch>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'diplomat'

class CheckConsulServiceS < Sensu::Plugin::Check::CLI
  option :consul,
         description: 'consul server',
         long: '--consul SERVER',
         default: 'http://localhost:8500'

  def run
    Diplomat.configure do |dc|
      dc.url = config[:consul]
    end

    results = []

    # Process all of the nonpassing service checks
    Diplomat::Health.state('any').each do |s|
      next if s['Status'] == 'passing'
      results.push "#{s['ServiceName']} on #{s['Node']}"
    end

    critical results.join(', ') unless results.empty?
    ok
  end
end
