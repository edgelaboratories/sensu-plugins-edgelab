#! /usr/bin/env ruby
#
# check-cassandra-schema
#
# DESCRIPTION:
#   This plugin uses Apache Cassandra's `nodetool` to see if any node in the
#   cluster are not in the correct state.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: english
#   Cassandra's nodetool
#
# LICENSE:
#   Copyright 2017 Jonathan Ballet <jballet@edgelab.ch>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'English'

#
# Check Cassandra Node
#
class CheckCassandraNode < Sensu::Plugin::Check::CLI
  option :hostname,
         short: '-h HOSTNAME',
         long: '--host HOSTNAME',
         description: 'cassandra hostname',
         default: 'localhost'

  option :port,
         short: '-P PORT',
         long: '--port PORT',
         description: 'cassandra JMX port',
         default: '7199'

  # Execute Cassandra's 'nodetool' and return output as string
  def nodetool_cmd(cmd)
    out = `nodetool -h #{config[:hostname]} -p #{config[:port]} #{cmd} 2>&1`
    [out, $CHILD_STATUS]
  end

  def run
    out, rc = nodetool_cmd('status')
    if rc != 0
      puts rc
      critical(out)
    end

    error_nodes = []
    warning_nodes = []
    ok_nodes = []

    total_load = 0
    nodes = {}

    out.each_line do |line|
      if m = line.match(/^([UD])([NLJM])\s+([0-9\.]+)\s+([0-9\.]+) ([a-zA-Z]+)\s+([0-9]+).*\s+([^ ]+)$/) # rubocop:disable all
        status = m[1]
        state = m[2]
        address = m[3]
        load_ = m[4]
        unit = m[5]
        rack = m[6]

        factor = 1
        if unit == 'GiB'
          factor = 1024 * 1024 * 1024
        elsif unit == 'MiB'
          factor = 1024 * 1024
        elsif unit == 'KiB'
          factor = 1024
        end

        nodes[address] = {
          status: status,
          state: state,
          load: (load_.to_f * factor),
          rack: rack
        }
        total_load += nodes[address][:load]
      end
    end

    nodes.each do |address, node|
      if node[:status] != 'U'
        error_nodes << "Node #{address} is Down #{node[:status]}"
        next
      end

      if node[:state] == 'J'
        # TODO: is that interesting to have?
        # content = 100 * node[:load] / total_load
        # ideal = 100 / nodes.count
        # warning_nodes << "#{address} is joining (has #{content.round(1)}%, ideal=#{ideal.round(1)}%)"
        warning_nodes << "#{address} is joining"
        next
      end

      ok_nodes << "#{address} is normal (#{node[:status]}#{node[:state]})"
    end

    if error_nodes.count.positive?
      criticial error_nodes.join(', ')
    elsif warning_nodes.positive?
      warning warning_nodes.join(', ')
    else
      ok ok_nodes.join(', ')
    end
  end
end
