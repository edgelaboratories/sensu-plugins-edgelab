#! /usr/bin/env ruby
# frozen_string_literal: true

#
#   check-nomad-jobs
#
# DESCRIPTION:
#   This plugin nomad registered jobs status.
#

require 'sensu-plugin/check/cli'
require 'rest-client'
require 'json'

class CheckNomadAllocations < Sensu::Plugin::Check::CLI
  option :nomad,
         description: 'nomad server address',
         long: '--nomad SERVER',
         default: 'http://localhost:4646'
  option :alloc_starting_time,
         description: '',
         long: '--alloc-starting-time',
         default: 300

  # Call Nomad api and parse the json response
  def api_call(endpoint)
    url = config[:nomad] + endpoint
    begin
      response = RestClient.get(url)
    rescue => e
      critical "Unable to connect to Nomad: #{e}"
    else
      begin
        return JSON.parse(response)
      rescue => e
        critical "Unable to parse json in response: #{e}"
      end
    end
  end

  # Check that allocations are in the desired status
  def check_allocations(job, failed)
    allocations = api_call "/v1/job/#{job['ID']}/allocations"

    allocations.each do |alloc|
      if alloc['DesiredStatus'] == 'run'
        # Batch stay in run DesiredStatus even if task completed successfully.
        next if job['Type'] == 'batch' and alloc['ClientStatus'] == 'complete'

        alloc['TaskStates'].each do |_, state|
          if state['State'] == 'dead'
              failed << "Alloc #{alloc['Name']} is dead but desired status is 'run'"

          # Check that pending alloc are not too old
          elsif state['State'] == 'pending'
            # Get the last event timestamp (which is in microseconds in Nomad)
            event_time = state['Events'][-1]['Time'] / 1_000_000_000
            starting_time = (Time.new - Time.at(event_time)).round

            if starting_time > config[:alloc_starting_time]
              failed << "Alloc #{alloc['Name']} is pending since #{starting_time} seconds"

              # No need to check other task in the same task group.
              break
            end

          end
        end
      end
    end
  end

  def run
    jobs = api_call '/v1/jobs'
    if jobs.empty?
      critical 'No jobs found in Nomad.'
    end

    failed = []

    jobs.each do |job|
      check_allocations job, failed
    end

    if failed.any?
      critical "#{failed.length} failed jobs: " + failed.join(', ')
    else
      ok "#{jobs.length} jobs running"
    end
  end
end
