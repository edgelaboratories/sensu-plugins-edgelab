#! /usr/bin/env ruby
# frozen_string_literal: true

require 'docker-api'
require 'diplomat'
require 'sensu-plugin/check/cli'

class CheckDockerSwarmCluster < Sensu::Plugin::Check::CLI
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

    begin
      count = Docker::Container.all(running: true).size.to_i
      ok "Swarm running with #{count} containers (leader: #{leader})"
    rescue => e
      critical "Swarm error: #{e.inspect} (leader: #{leader})"
    end
  end
end
