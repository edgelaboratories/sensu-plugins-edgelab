#! /usr/bin/env ruby
#
# Check Logstash pipeline to Elasticsearch
# ===
#
# DESCRIPTION:
# This plugin sends a message to Logstash and check if it arrives correctly in
# Elasticsearch.
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: rest-client
#
# LICENSE:
# Copyright 2017 Jonathan Ballet <jballet@edgelab.ch>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu-plugin/check/cli'
require 'rest-client'

require 'digest'
require 'json'
require 'socket'
require 'time'
require 'timeout'

class CheckLogstashPipeline < Sensu::Plugin::Check::CLI
  option :duration_warning,
         description: 'Warn if lookup time greater than TIME',
         short: '-w TIME',
         long: '--warning TIME',
         proc: proc(&:to_i),
         default: 15

  option :duration_critical,
         description: 'Error if lookup time greater than TIME',
         short: '-c TIME',
         long: '--critical TIME',
         proc: proc(&:to_i),
         default: 40

  option :logstash_host,
         description: 'Logstash hostname',
         long: '--logstash-host HOSTNAME',
         default: 'json-tcp.logstash.service.consul'

  option :logstash_port,
         description: 'Logstash TCP port',
         long: '--logstash-port PORTT',
         proc: proc(&:to_i),
         default: 10_515

  option :elasticsearch_url,
         description: 'Elasticsearch URL',
         long: '--elasticsearch URL',
         default: 'http://elasticsearch.service.consul:9200'

  option :timeout,
         description: 'Timeout waiting for the event to show up in Elasticsearch',
         short: '-t TIME',
         long: '--timeout TIME',
         proc: proc(&:to_i),
         default: 60

  option :elaticsearch_request_interval,
         description: 'Duration to wait between each Elasticsearch request',
         short: '-i TIME',
         long: '--interval TIME',
         proc: proc(&:to_i),
         default: 2

  def run
    sent_at = Time.now
    message = Digest::SHA256.hexdigest sent_at.to_i.to_s

    msg = {
      service: {
        name: 'logstash-check'
      },
      message: message,
      sent_at: sent_at.iso8601(10)
    }

    socket = TCPSocket.new(config[:logstash_host],
                           config[:logstash_port])
    socket.puts(JSON.generate(msg))
    socket.close

    msearch1 = {index: ["logstash-*"]}
    msearch2 = {
      size: 5,
      query: {
        bool: {
          must: [
            { query_string: { query: message } },
            {
              range: {
                "@timestamp": {
                  gte: sent_at.to_i,
                  lte: sent_at.to_i + 60 * 5, # + 5 minutes
                  format: 'epoch_second'
                }
              }
            }
          ]
        }
      }
    }

    body = "#{JSON.generate(msearch1)}\n#{JSON.generate(msearch2)}\n"
    url = "#{config[:elasticsearch_url]}/_msearch"

    tries = 0
    found = 0

    while Time.now.to_i - sent_at.to_i < config[:timeout]
      sleep config[:elaticsearch_request_interval]
      tries += 1
      response = RestClient.post(url, body)
      found = JSON.parse(response)['responses'][0]['hits']['total']
      break if found > 0
    end

    duration = Time.now.to_i - sent_at.to_i

    if found <= 0
      critical "Event #{message} NOT found"
    end

    msg = "Event found (duration=#{duration}s, requests=#{tries}, results=#{found})"
    if duration > config[:duration_critical]
      critical msg
    elsif duration > config[:duration_warning]
      warning msg
    else
      ok msg
    end
  end
end
