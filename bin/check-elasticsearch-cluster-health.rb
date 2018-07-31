#! /usr/bin/env ruby
#
#   check-elasticsearch-cluster-health
#
# DESCRIPTION:
#   This plugin checks the Elasticsearch cluster health from its status and number of nodes present.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: elasticsearch
#
# USAGE:
#   Checks against the Elasticsearch api for cluster health using the
#   Elasticsearch gem
#
# NOTES:
#   Adapted from sensu-plugins-elasticsearch `check-es-cluster-health.rb`
#
# LICENSE:
#   Jonathan Ballet <jballet@edgelab.ch>
#   Brendan Gibat <brendan.gibat@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-plugin/check/cli'
require 'elasticsearch'

class ESClusterHealth < Sensu::Plugin::Check::CLI
  option :host,
         description: 'Elasticsearch host',
         short: '-h HOST',
         long: '--host HOST',
         default: 'localhost'

  option :port,
         description: 'Elasticsearch port',
         short: '-p PORT',
         long: '--port PORT',
         proc: proc(&:to_i),
         default: 9200

  option :scheme,
         description: 'Elasticsearch connection scheme, defaults to https for authenticated connections',
         short: '-s SCHEME',
         long: '--scheme SCHEME'

  option :password,
         description: 'Elasticsearch connection password',
         short: '-P PASSWORD',
         long: '--password PASSWORD'

  option :user,
         description: 'Elasticsearch connection user',
         short: '-u USER',
         long: '--user USER'

  option :timeout,
         description: 'Elasticsearch query timeout in seconds',
         short: '-t TIMEOUT',
         long: '--timeout TIMEOUT',
         proc: proc(&:to_i),
         default: 30

  option :min_nodes,
         description: 'Minimum of nodes that should be present in the cluster',
         short: '-n NB_NODES',
         long: '--minimum-nodes NB_NODES',
         proc: proc(&:to_i),
         default: 0

  # From sensu-plugins-elasticsearch's ElasticsearchCommon
  def client
    transport_class = nil

    host = {
      host:               config[:host],
      port:               config[:port],
      request_timeout:    config[:timeout],
      scheme:             config[:scheme]
    }

    if !config[:user].nil? && !config[:password].nil?
      host[:user] = config[:user]
      host[:password] = config[:password]
      host[:scheme] = 'https' unless config[:scheme]
    end

    transport_options = {}

    if config[:headers]

      headers = {}

      config[:headers].split(',').each do |header|
        h, v = header.split(':', 2)
        headers[h.strip] = v.strip
      end

      transport_options[:headers] = headers

    end

    @client ||= Elasticsearch::Client.new(transport_class: transport_class, hosts: [host], transport_options: transport_options)
  end

  def run
    options = {}
    health = client.cluster.health options

    message = ''

    case health['status']
    when 'yellow'
      cb = method(:warning)
      message += 'Cluster state is Yellow'
    when 'red'
      cb = method(:critical)
      critical 'Cluster state is Red'
    when 'green'
      cb = method(:ok)
      message = 'Cluster state is Green'
    else
      cb = method(:unknown)
      message = "Cluster state is in an unknown health: #{health['status']}"
    end

    message += " (#{health['active_shards_percent_as_number'].round(2)} % of active shards)"

    if health['number_of_nodes'] < config[:min_nodes]
      cb = method(:critical)
      message = "Not enough nodes: #{health['number_of_nodes']} < #{config[:min_nodes]} - " + message
    end

    cb.call(message)
  end
end
