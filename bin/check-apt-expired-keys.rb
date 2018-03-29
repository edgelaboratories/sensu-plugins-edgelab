#! /usr/bin/env ruby
# frozen_string_literal: true

#
#   check-apt-expired-keys
#
# DESCRIPTION:
#   This plugin reports expired GPG key used for APT signing.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Debian
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#   example commands
#
# NOTES:
#   Does it behave differently on specific platforms, specific use cases, etc
#
# LICENSE:
#   Copyright 2015 EdgeLaboratories.
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class APTKey < Sensu::Plugin::Check::CLI
  def run
    # Must be executed as root in order to access APT keys list
    if Process.uid != 0
      return unknown 'Must be executed as root user'
    end

    expired = expired_keys

    if expired.count.positive?
      if expired.count == 1
        verb = 'is'
        noun = 'key'
      else
        verb = 'are'
        noun = 'keys'
      end
      warning "There #{verb} #{expired.count} expired APT #{noun}: #{expired.join('; ')}"
    else
      ok 'No APT expired keys'
    end
  end

  def expired_keys
    expired = []
    IO.popen('apt-key list') do |cmd|
      current_key_id = nil
      current_key_name = nil

      # We try to parse output like this:
      # pub   2048R/B999A372 2010-08-12 [expired: 2015-08-13]
      # uid          Riptano Package Repository <paul@riptano.com>

      cmd.each do |line|
        # Parse and extract the expired public key ID
        match = /^pub[ ]+[^\/]+\/(.*) .* \[expired: /.match(line)
        unless match.nil?
          current_key_id = match.captures[0]
        end

        # Try to get the more user-friendly name. Sometimes, it doesn't
        # contain enough information to be useful, but it still
        # slightly better than the key ID.
        match = /^uid[ ]+(.*)$/.match(line)
        unless match.nil?
          current_key_name = match.captures[0]
        end

        # If we reach an empty line and we parsed expired key, save
        # them and reset everything for the next keys after.
        if line =~ /^$/
          if current_key_id
            expired.push "#{current_key_name || 'unknown key uid'} (#{current_key_id})"
          end
          current_key_id = nil
          current_key_name = nil
        end
      end
    end
    expired
  end
end
