require 'net/http'
require 'uri'
require 'tmpdir'
require 'fileutils'
require_relative '../log/log'

def create_tmp_file(filename)
  File.join(Dir.tmpdir, filename)
end

def printable_request(response)
  str = 'request'
  str += "status: #{response.code}"
  str += "body: #{response.body}"
  str
end

def download_to_path(url, path)
  uri = URI.parse(url)
  request = Net::HTTP::Get.new(uri.request_uri)
  http_object = Net::HTTP.new(uri.host, uri.port)
  http_object.use_ssl = (uri.scheme == 'https')
  response = http_object.start do |http|
    http.request(request)
  end

  raise printable_request(response) unless response.code == '200'

  io = open(path, 'w')
  chunk = response.read_body
  io.write(chunk)
end

def download_to_tmp_file(url, filename)
  path = nil
  if url.start_with?('file://')
    path = url.sub('file://', '')
    raise "Certificate not exist at: #{path}" unless File.exist?(path)
  else
    path = create_tmp_file(filename)
    download_to_path(url, path)
  end
  path
end

def download_profile(profile)
  home_dir = ENV['HOME']
  raise 'failed to determine Xcode Provisioning Profiles dir: HOME env not set' if home_dir.to_s.empty?

  profiles_dir = File.join(home_dir, 'Library/MobileDevice/Provisioning Profiles')
  FileUtils.mkdir_p(profiles_dir) unless File.directory?(profiles_dir)

  profile_path = File.join(profiles_dir, profile.uuid + '.mobileprovision')
  log_warning("Provisioning Profile already exists at: #{profile_path}, overwriting...") if File.file?(profile_path)

  File.write(profile_path, profile.download)
  profile_path
end
