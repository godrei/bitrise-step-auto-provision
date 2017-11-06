require 'net/http'
require 'uri'
require 'tmpdir'
require 'fileutils'
require_relative '../log/log'

def create_tmp_file(filename)
  File.join(Dir.tmpdir, filename)
end

def download_file(url, path)
  return url.sub('file://', '') if url.start_with?('file://')

  uri = URI.parse(url)

  request = Net::HTTP::Get.new(uri.request_uri)

  http_object = Net::HTTP.new(uri.host, uri.port)
  http_object.use_ssl = true if uri.scheme == 'https'

  response = http_object.start do |http|
    http.request(request)
  end

  unless response.code == '200'
    log_debug('')
    log_debug('failed to download file')
    log_debug("status: #{response.code}")
    log_debug("body: #{response.body}")

    raise 'failed to download file'
  end

  io = open(path, 'w')
  chunk = response.read_body
  io.write(chunk)
end

def create_certificate_path_passphrase_map(certificate_urls, passphrases)
  certificate_passphrase_map = {}

  certificate_urls.each_with_index do |certificate_url, idx|
    certificate_path = nil
    if certificate_url.start_with?('file://')
      certificate_path = certificate_url.sub('file://', '')
      raise "Certificate not exist at: #{certificate_path}" unless File.exist?(certificate_path)
    else
      certificate_path = create_tmp_file("Certificate#{idx}.p12")
      download_file(certificate_url, certificate_path)
    end

    passphrase = passphrases[idx]
    certificate_passphrase_map[certificate_path] = passphrase
  end

  certificate_passphrase_map
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
