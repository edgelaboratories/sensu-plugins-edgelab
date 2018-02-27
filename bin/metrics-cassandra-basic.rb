#!/usr/bin/env ruby
#
#   metrics-cassandra-basic
#
# DESCRIPTION:
#   Get basic metrics about a Cassandra cluster
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: cassandra
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2018 EdgeLaboratories.
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'socket'
require 'cassandra'

#
# Cassandra Basic Metrics
#
class CassandraBasicMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :hostname,
         short: '-h HOSTNAME',
         long: '--host HOSTNAME',
         description: 'Cassandra hostname',
         default: 'localhost'

  option :port,
         short: '-P PORT',
         long: '--port PORT',
         description: 'Cassandra CQL port',
         default: 9042

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.cassandra-cluster"

  def safe_name(name)
    name.gsub!(/[^a-zA-Z0-9]/, '_')  # convert all other chars to _
    name.gsub!(/[_]*$/, '')          # remove any _'s at end of the string
    name.gsub!(/[_]{2,}/, '_')       # convert sequence of multiple _'s to single _
    name
  end

  def connect
    @cluster = Cassandra.cluster(
      hosts: [config[:hostname]],
      port: config[:port],
    )
  end

  def parse_keyspace
    output "#{config[:scheme]}.#{safe_name(@cluster.name)}.nodes.count", @cluster.hosts.length, @timestamp
    output "#{config[:scheme]}.#{safe_name(@cluster.name)}.keyspaces.count", @cluster.keyspaces.length, @timestamp

    session = @cluster.connect('system_schema')
    cf = session.execute('SELECT table_name FROM tables')
    output "#{config[:scheme]}.#{safe_name(@cluster.name)}.column_families.count", cf.length, @timestamp
  end

  def run
    @timestamp = Time.now.to_i

    connect
    parse_keyspace

    ok
  end
end
