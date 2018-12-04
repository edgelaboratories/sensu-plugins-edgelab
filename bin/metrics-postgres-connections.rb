#! /usr/bin/env ruby
#
#   metric-postgres-connections
#
# DESCRIPTION:
#
#   This plugin collects postgres connection metrics
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: pg
#
# USAGE:
#   ./metric-postgres-connections.rb -u db_user -p db_pass -h db_host -d db
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2012 Kwarter, Inc <platforms@kwarter.com>
#   Author Gilles Devaux <gilles.devaux@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'pg'
require 'socket'

class PostgresStatsDBMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :user,
         description: 'Postgres User',
         short: '-u USER',
         long: '--user USER'

  option :password,
         description: 'Postgres Password',
         short: '-p PASS',
         long: '--password PASS'

  option :hostname,
         description: 'Hostname to login to',
         short: '-h HOST',
         long: '--hostname HOST'

  option :port,
         description: 'Database port',
         short: '-P PORT',
         long: '--port PORT'

  option :database,
         description: 'Database name',
         short: '-d DB',
         long: '--db DB',
         default: 'postgres'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to $queue_name.$metric',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.postgresql"

  option :timeout,
         description: 'Connection timeout (seconds)',
         short: '-T TIMEOUT',
         long: '--timeout TIMEOUT',
         default: nil

  def run
    timestamp = Time.now.to_i
    conn      = PG.connect(host: config[:hostname],
                           dbname: config[:database],
                           user: config[:user],
                           password: config[:password],
                           port: config[:port],
                           connect_timeout: config[:timeout])

    # https://www.postgresql.org/docs/10/monitoring-stats.html#PG-STAT-ACTIVITY-VIEW
    # *state* field needs superuser privileges to read state of other users, otherwise we set it to *unknown_state*
    query = <<END_SQL
  SELECT usename, datname, replace(replace(replace(coalesce(state, 'unknown_state'), ' ', '_'), '(', ''), ')', '') as state, count(*)
    FROM pg_stat_activity WHERE usename IS NOT NULL AND datname IS NOT NULL
    GROUP BY usename, datname, state;
END_SQL

    conn.exec(query) do |result|
      result.each do |row|
        output "#{config[:scheme]}.connections.#{row['usename']}.#{row['datname']}.#{row['state']}", row['count'], timestamp
      end
    end

    ok
  end
end
