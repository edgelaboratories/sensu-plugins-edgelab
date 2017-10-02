#!/usr/bin/env ruby
#  encoding: UTF-8
#
# Check RabbitMQ Queues Synchronised
# ===
#
# DESCRIPTION:
# This plugin checks that all mirrored queues which have slaves are synchronised.
#
# PLATFORMS:
#   Linux, BSD, Solaris
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: rest-client
#
# LICENSE:
# Copyright 2017 Cyril Gaudin <cyril.gaudin@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rest_client'
require 'sensu-plugins-rabbitmq'

# main plugin class
class CheckRabbitMQQueuesSynchronised < Sensu::Plugin::RabbitMQ::Check
  option :list_queues,
         description: 'If set, will ouput the list of all unsynchronised queues, otherwise only the count',
         long: '--list-queues',
         boolean: true,
         default: false

  def run
    @crit = []

    queues = get_queues config

    queues.each do |q|
      next unless q['durable'] # Non-durable queues are not concerned with synchronization
      nb_slaves = q['slave_nodes'].count
      unless nb_slaves == 0
        unsynchronised = nb_slaves - q['synchronised_slave_nodes'].count
        if unsynchronised != 0
          @crit << "#{q['name']}: #{unsynchronised} unsynchronised slave(s)"
        end
      end
    end
    if @crit.empty?
      ok
    elsif config[:list_queues]
      critical 'critical:' + @crit.join(' - ')
    else
      critical "critical: #{@crit.count} unsynchronised queues"
    end
  rescue Errno::ECONNREFUSED => e
    critical e.message
  rescue => e
    unknown e.message
  end

  def get_queues(config)
    url_prefix = config[:ssl] ? 'https' : 'http'
    options = {
      user: config[:username],
      password: config[:password]
    }

    resource = RestClient::Resource.new(
      "#{url_prefix}://#{config[:host]}:#{config[:port]}/api/queues",
      options
    )
    JSON.parse(resource.get)
  end
end
