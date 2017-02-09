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
         description: 'Nomad server URL',
         long: '--nomad SERVER',
         default: 'http://localhost:4646'
  option :alloc_starting_time,
         description: '',
         long: '--alloc-starting-time',
         default: 300

  # Call Nomad api and parse the JSON response
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
        critical "Unable to parse JSON in response: #{e}"
      end
    end
  end

  # Returning an array containing human readable explanation for placement failures
  def placement_failures_reasons(failed_eval)
    reasons = []
    failed_eval['FailedTGAllocs'].each do |_, metrics|
      metrics.fetch(:ClassFiltered, []).each do |class_, count|
        reasons << "Class #{class_} filtered #{count} nodes"
      end

      metrics.fetch(:ConstraintFiltered, []).each do |constraint, count|
        reasons << "Constraint #{constraint} filtered #{count} nodes"
      end

      if metrics['NodesExhausted'] > 0
        reasons << "Resources exhausted on #{metrics['NodesExhausted']} nodes"
      end

      metrics.fetch(:ClassExhausted, []).each do |class_, count|
        reasons << "Class #{class_} exhausted on #{count} nodes"
      end

      metrics.fetch('DimensionExhausted', []).each do |dimension, count|
        reasons << "#{dimension} on #{count} nodes"
      end
    end

    reasons
  end

  # Check that there is no failed evaluations
  def check_evaluations(job, failed)
    evaluations = api_call "/v1/job/#{job['ID']}/evaluations"

    blocked = false
    last_failed = nil

    evaluations.each do |evaluation|
      if evaluation['Status'] == 'blocked'
        blocked = true
      end

      next if evaluation['FailedTGAllocs'].nil?

      if last_failed.nil? || last_failed['CreateIndex'] < evaluation['CreateIndex']
        last_failed = evaluation
      end
    end

    if blocked && !last_failed.nil?
      failure_reasons = placement_failures_reasons last_failed

      if failure_reasons.any?
        failed << "#{job['ID']}: Placemement failure [" + failure_reasons.join(' / ') + ']'
      end
    end
  end

  # Check that allocations are in the desired status
  def check_allocations(job, failed)
    allocations = api_call "/v1/job/#{job['ID']}/allocations"

    allocations.each do |alloc|
      if alloc['DesiredStatus'] == 'run'
        # Batch stay in run DesiredStatus even if task completed successfully.
        next if job['Type'] == 'batch' && alloc['ClientStatus'] == 'complete'

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
      check_evaluations job, failed
      check_allocations job, failed
    end

    if failed.any?
      critical "#{failed.length} failed jobs: " + failed.join(', ')
    else
      ok "#{jobs.length} jobs running"
    end
  end
end
