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
         long: '--alloc-starting-time SECONDS',
         default: 300

  option :alloc_restarts_count,
         description: 'Limit number of restarts in restarts interval',
         long: '--alloc-restarts-count COUNT',
         default: 3

  option :alloc_restarts_interval,
         description: 'Interval in seconds for the limit number of restarts',
         long: '--alloc-restarts-interval SECONDS',
         default: 3600

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
      fetch = lambda do |key|
        if metrics.key?(key) && !metrics[key].nil?
          metrics[key]
        else
          {}
        end
      end

      fetch.call(:ClassFiltered).each do |class_, count|
        reasons << "Class #{class_} filtered #{count} nodes"
      end

      fetch.call(:ConstraintFiltered).each do |constraint, count|
        reasons << "Constraint #{constraint} filtered #{count} nodes"
      end

      if metrics['NodesExhausted'] > 0
        reasons << "Resources exhausted on #{metrics['NodesExhausted']} nodes"
      end

      fetch.call(:ClassExhausted).each do |class_, count|
        reasons << "Class #{class_} exhausted on #{count} nodes"
      end

      fetch.call('DimensionExhausted').each do |dimension, count|
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

    # System jobs don't have blocked evaluation, only one evaluation per job.
    if (job['Type'] == 'system' || blocked) && !last_failed.nil?
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

  # Check that running allocations are not restarting endlessly.
  def check_restarts(job, failed)
    allocations = api_call "/v1/job/#{job['ID']}/allocations"
    now = Time.new.to_i

    allocations.each do |alloc|
      if %w(running pending).include? alloc['ClientStatus']
        alloc['TaskStates'].each do |_, state|
          restarts = 0
          state['Events'].each do |event|
            if event['Type'] == 'Restarting'
              event_time = event['Time'] / 1_000_000_000
              if (now - event_time) < config[:alloc_restarts_interval].to_i
                restarts += 1
              end
            end
          end

          if restarts >= config[:alloc_restarts_count].to_i
            failed << "Alloc #{alloc['Name']} restart #{restarts} times"
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
      check_restarts job, failed
    end

    if failed.any?
      critical "#{failed.length} failed jobs: " + failed.join(', ')
    else
      ok "#{jobs.length} jobs running"
    end
  end
end
