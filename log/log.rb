def log_info(message)
  puts "\e[34m#{message}\e[0m"
end

def log_details(message)
  puts message.to_s
end

def log_done(message)
  puts "\e[32m#{message}\e[0m"
end

def log_warning(message)
  puts "\e[33m#{message}\e[0m"
end

def log_error(message)
  puts "\e[31m#{message}\e[0m"
end

def log_debug(message)
  return unless DEBUG_LOG
  puts message.to_s
end

def log_secret_input(key, value)
  puts key + ': ***' unless value.to_s.empty?
  puts key + ':' if value.to_s.empty?
end

def log_input(key, value)
  puts key + ': ' + value
end
