require 'logger'

module SneaqlStandard
  Log = Logger.new(STDOUT)
end

def logger
  SneaqlStandard::Log
end

# custom formatter provides logging with thread id and multi-line
# entries each receiving their own log prefix
logger.formatter = proc do |severity, datetime, _progname, msg|
  t = ''
  msg.to_s.split(/\n+/).each do |line|
    t += "[#{severity}] #{datetime} tid#{Thread.current.object_id}: #{line}\n"
  end
  t
end
