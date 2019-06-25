#! /usr/bin/env ruby
# frozen_string_literal: true

#
#   check-nomad-leader
#
# DESCRIPTION:
#   This plugin checks there's a Nomad server node elected as a leader.
#

require 'sensu-plugin/check/cli'
require 'rest-client'
require 'json'

class CheckNomadLeader < Sensu::Plugin::Check::CLI
  option :nomad,
         description: 'Nomad server URL',
         long: '--nomad SERVER',
         default: 'http://localhost:4646'

  # Actually no token is needed to query /v1/status/... endpoints
  # We still add the parameter in case it changes in future versions.
  option :token,
         description: 'Nomad ACL token to use',
         long: '--token TOKEN',
         default: ''

  # Call Nomad api and parse the json response
  def api_call(endpoint)
    url = config[:nomad] + endpoint
    headers = {}
    if config[:token]
      headers['X-Nomad-Token'] = config[:token]
    end

    begin
      response = RestClient.get(url, headers)
    rescue RestClient::ExceptionWithResponse => e
      critical "Error #{e.http_code}: #{e.response}"
    rescue => e
      critical "Unable to contact Nomad: #{e}"
    else
      # Sensu ships with Ruby 2.3.0, which doesn't know how to parse strings
      # as top-level element.
      value = "{\"leader\": #{response}}"
      begin
        return JSON.parse(value)['leader']
      rescue => e
        critical "Unable to parse JSON in response: #{e}"
      end
    end
  end

  def run
    leader = api_call '/v1/status/leader'
    ok "Nomad leader at #{leader}"
  end
end
