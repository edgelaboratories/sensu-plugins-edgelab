#!/usr/bin/env ruby
#
# Sensu Handler: hipchat
#
# This handler script is used to send notifications to Hipchat rooms.
#
# Input:
#   @event - Event attributes.
#      @event['action'] - Property to figure out the event type i.e. whether it is create or resolve.
#      @event['check'] - Map of attributes from the check config which is calling this handler
#      @event['client'] - Map of attributes from the client config for the clients from which this event is generated.
#   option: json_config - By default, assumes the hipchat config parameters are in the "hipchat" top-level json key.
#                         This command line option allows to specify a custom json key.
#
# Output:
#    Green coloured notification on the Hipchat room if a resolve event is seen.
#    Yellow coloured notification used to notify warning if a create event is seen with a status of 1
#    Red coloured notification used to notify critical if a create event is seen with a status other than 1
#
# Note: The handler config is fetched and merged from all json config files. The "hipchat" json key is used by default which can
#       be overridden with the "json_config" command line option. The hipchat room could also be configured on a per client basis
#       by defining the "hipchat_room" attribute in the client config file. This will override the default hipchat room where the
#       alerts are being routed to for that particular client.

require 'sensu-handler'
require 'hipchat'
require 'timeout'
require 'erb'
require 'json'

class HipChatNotif < Sensu::Handler
  option :json_config,
         description: 'JSON config key name',
         short: '-j JsonKeyName',
         long: '--json_config JsonKeyName',
         required: false,
         default: 'hipchat'

  def event_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def handle
    json_config = config[:json_config]
    server_url = settings[json_config]['server_url'] || 'https://api.hipchat.com'
    apiversion = settings[json_config]['apiversion'] || 'v1'
    proxy_url = settings[json_config]['proxy_url']
    hipchatmsg = HipChat::Client.new(settings[json_config]['apikey'], api_version: apiversion, http_proxy: proxy_url, server_url: server_url)
    from = settings[json_config]['from'] || 'Sensu'

    room = @event['client']['hipchat_room'] || @event['check']['hipchat_room'] || settings[json_config]['room']

    mentions = @event['check']['hipchat_mentions'] || []
    if not mentions.kind_of?(Array)
      mentions = [mentions]
    end
    mentions = mentions.map{ |e| String(e) }

    puts "Will mentions: #{mentions}"
    puts "Will send to room: #{room}"

    message_template = settings[json_config]['message_template']
    message_format = settings[json_config]['message_format'] || 'html'

    # If the playbook attribute exists and is a URL, "[<a href='url'>playbook</a>]" will be output.
    # To control the link name, set the playbook value to the HTML output you would like.
    playbook = ''
    if @event['check']['playbook']
      begin
        uri = URI.parse(@event['check']['playbook'])
        playbook << if %w( http https ).include?(uri.scheme)
                      "  [<a href='#{@event['check']['playbook']}'>Playbook</a>]"
                    else
                      "  Playbook:  #{@event['check']['playbook']}"
                    end
      rescue
        playbook << "  Playbook:  #{@event['check']['playbook']}"
      end
    end

    if message_template && File.readable?(message_template)
      template = File.read(message_template)
    else
      template = '''<%=
      [
        @event["action"].eql?("resolve") ? "RESOLVED" : "ALERT",
        " - [#{event_name}] - ",
        @event["check"]["notification"] || @event["check"]["output"],
        playbook,
        "."
      ].join
      %>'''
    end
    eruby = ERB.new(template)
    message = eruby.result(binding)

    if @event['action'].eql?('resolve')
      color = 'green'
      notify = false
    elsif @event['action'].eql?('flapping')
      color = [0, 1].include?(@event['check']['status']) ? 'yellow' : 'red'
      notify = false
    else
      color = @event['check']['status'] == 1 ? 'yellow' : 'red'
      notify = true
    end

    mentions = mentions.map{|user| "@#{user}"}.join(", ")

    if mentions and message_format != "html" and not @event['action'].eql?('resolve')
      # Add the mention only if the action is not resolved.
      message = "#{message} #{mentions}"
    end

    begin
      Timeout.timeout(5) do
        hipchatmsg[room].send(from, message,
                              color: color,
                              notify: notify,
                              message_format: message_format)
      end
    rescue Timeout::Error
      puts "Timed out while attempting to message #{room}"
    end

    if message_format == 'html' and mentions and not @event['action'].eql?('resolve')
      # HTML messages won't notify when using @mentions.
      begin
        Timeout.timeout(5) do
          hipchatmsg[room].send(from, mentions,
                                color: color,
                                message_format: "text")
        end
      rescue Timeout::Error
        puts "Timed out while attempting to send mentions to #{room}"
      end
    end
  end
end
