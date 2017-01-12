#! /usr/bin/env ruby
# frozen_string_literal: true

require 'docker-api'
require 'diplomat'
require 'sensu-plugin/metric/cli'

class DockerContainerMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: 'swarm'

  option :consul_url,
         short: '-c CONSUL_URL',
         long: '--consul CONSUL_URL',
         default: 'http://localhost:8500'

  option :cert_path,
         short: '-t CERT_PATH',
         long: '--cert-path CERT_PATH',
         default: '~/.docker'

  option :tls_enabled,
         short: '-t',
         long: '--tls-enabled',
         default: false

  def run
    swarm_metrics
    ok
  end

  def swarm_metrics
    Diplomat.configure do |consul|
      consul.url = config[:consul_url]
    end

    begin
      leader = Diplomat::Kv.get('docker/swarm/leader')
    rescue => e
      critical "Unable to query Consul on #{config[:consul_url]} for Swarm leader: #{e.inspect}"
    end

    if config[:tls_enabled]
      scheme = 'https'
      cert_path = File.expand_path(config[:cert_path])
      Docker.options = {
        client_cert: File.join(cert_path, 'cert.pem'),
        client_key:  File.join(cert_path, 'key.pem'),
        ssl_ca_file: File.join(cert_path, 'ca.pem'),
        scheme: scheme
      }
    else
      scheme = 'http'
      Docker.options = {
        scheme: scheme
      }
    end

    Docker.url = "#{scheme}://#{leader}"

    timestamp = Time.now.to_i

    infos = Docker.info

    prefix = config[:scheme]

    output "#{prefix}.containers.running", infos['ContainersRunning'], timestamp
    output "#{prefix}.containers.paused", infos['ContainersPaused'], timestamp
    output "#{prefix}.containers.stopped", infos['ContainersStopped'], timestamp

    output "#{prefix}.images", infos['Images'], timestamp

    output "#{prefix}.size.cpus", infos['NCPU'], timestamp
    output "#{prefix}.size.memory", infos['MemTotal'], timestamp

    nodes = {
      'healthy': 0,
      'pending': 0,
      'unhealthy': 0
    }
    infos['DriverStatus'].each do |info|
      key, value = info

      if key.end_with?(' Status')
        status = value.downcase

        # Just in case there are other statuses...
        unless nodes.key?(status)
          nodes[status] = 0
        end
        nodes[status] += 1
      end
    end

    nodes.each do |status, count|
      output "#{prefix}.nodes.status.#{status}", count, timestamp
    end
  end
end
