#!/usr/bin/env ruby
#
# metrics-redis-key-pattern
#
# DESCRIPTION:
#   Count number of keys by a pattern.
#
# OUTPUT:
#   metric-data
#
# PLATFORMS:
#   Linux, Windows, BSD, Solaris, etc
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: redis
#
# USAGE:
#
# NOTES:
#
# LICENSE:
#   Jonathan Ballet <jballet@edgelab.ch>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-plugin/metric/cli'
require 'redis'

class RedisKeyPatternMetric < Sensu::Plugin::Metric::CLI::Graphite
  option :host,
         short: '-h HOST',
         long: '--host HOST',
         description: 'Redis Host to connect to',
         default: '127.0.0.1'

  option :port,
         short: '-p PORT',
         long: '--port PORT',
         description: 'Redis Port to connect to',
         proc: proc(&:to_i),
         default: 6379

  option :password,
         short: '-P PASSWORD',
         long: '--password PASSWORD',
         description: 'Redis Password to connect with'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.redis"

  option :nb_db,
         description: 'Number of databases to scan (default 16)',
         short: '-n NUM_DATABASES',
         long: '--number-databases NUM_DATABASES',
         proc: proc(&:to_i),
         default: 16

  option :segments,
         description: 'Number of key segments to measure',
         long: '--segments SEGMENTS',
         proc: proc(&:to_i),
         default: 1

  option :key_slice,
         description: 'Slice where to split the key from',
         long: '--key-slice KEY_SLICE',
         proc: proc(&:to_i),
         default: 30

  option :split_char,
         description: 'Which character to split they key',
         long: '--split-char SPLIT_CHAR',
         default: ':'

  def run
    options = { host: config[:host], port: config[:port] }
    options[:password] = config[:password] if config[:password]
    redis = Redis.new(options)

    (0..(config[:nb_db] - 1)).each do |db|
      begin
        redis.select(db)
      rescue Redis::CommandError
        # Selected database doesn't exist, it's probably we iterated over all
        # the databases of this Redis instance.
        break
      end
      counter = Hash.new(0)

      redis.scan_each do |key|
        head = key.byteslice(0, config[:key_slice]) \
                  .encode('utf-8',
                          invalid: :replace,
                          undef: :replace,
                          replace: '')
        head = head.split(config[:split_char])[0, config[:segments]].each { |s| s.tr('.', '_') }.join('.')
        counter[head] += 1
      end

      counter.each { |key, count| output "#{config[:scheme]}.db.#{db}.patterns.#{key}", count }
    end
    ok
  end
end
