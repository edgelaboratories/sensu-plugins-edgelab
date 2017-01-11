#! /usr/bin/env ruby

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

  # Return, as array of hash, all registered jobs in Nomad
  def nomad_jobs
    url = config[:nomad] + '/v1/jobs'
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

  def run
    jobs = nomad_jobs
    if jobs.empty?
      critical 'No jobs found in Nomad.'
    end

    failed = []

    jobs.each do |job|
      job['JobSummary']['Summary'].each do |group, summary|
        if summary['Failed'] != 0
          failed << "#{job['Name']}.#{group}"
        end
      end
    end

    if failed.any?
      critical "#{failed.length} failed jobs: " + failed.join(', ')
    else
      ok "#{jobs.length} jobs running"
    end
  end
end
