require 'net/http'
require 'uri'
require 'json'

require 'fastlane'
require 'spaceship'

require_relative 'log/log'
require_relative 'bitrise/bitrise'
require_relative 'xcodeproj/xcodeproj'
require_relative 'auto-provision/analyzer'
require_relative 'auto-provision/authenticator'
require_relative 'auto-provision/downloader'
require_relative 'auto-provision/generator'
require_relative 'auto-provision/const'
require_relative 'auto-provision/app_services'

DEBUG_LOG = true

begin
  # Params
  build_url = ENV['build_url'] || ''
  build_api_token = ENV['build_api_token'] || ''
  team_id = ENV['team_id'] || ''

  certificate_urls = ENV['certificate_urls'] || ''
  certificate_passphrases = ENV['certificate_passphrases'] || ''
  distributon_type = ENV['distributon_type'] || ''
  project_path = ENV['project_path'] || ''

  project = Project.new(project_path)
  project_targets = project.project_targets_map
  puts "project_targets: #{project_targets}"

  project_targets.each do |path, targets|
    targets.each do |target|
      settings = project.xcodebuild_target_build_settings(path, target)
      bundle_id = project.bundle_id_build_settings(settings)
      puts "bundle_id: #{bundle_id}"

      entitlements = project.entitlements_path_build_settings(settings, File.dirname(path))
      puts "entitlements: #{entitlements}"
    end
  end
  exit 1

  puts

  log_info('authentication Params:')
  log_input('build_url', build_url)
  log_input('build_api_token', build_api_token)
  log_input('team_id', team_id)

  log_info('auto-provision Params:')
  log_input('certificate_urls', certificate_urls)
  log_input('certificate_passphrases', certificate_passphrases)
  log_input('distributon_type', distributon_type)
  log_input('distributon_type', distributon_type)
  log_input('distributon_type', distributon_type)

  puts

  raise 'missing: build_url' if build_url.empty?
  raise 'missing: build_api_token' if build_api_token.empty?
  raise 'missing: team_id' if team_id.empty?

  raise 'missing: certificate_urls' if certificate_urls.empty?
  raise 'missing: certificate_passphrases' if certificate_passphrases.empty?
  raise 'missing: distributon_type' if distributon_type.empty?

  # Developer portal data
  response = get_developer_portal_data(build_url, build_api_token)
  log_debug('')
  log_debug("response.code: #{response.code}")
  log_debug("response.body: #{response.body}")

  if response.code != '200'
    log_debug('')
    log_debug('failed to get developer portal data')
    log_debug("status: #{response.code}")
    log_debug("body: #{response.body}")

    developer_portal_data = JSON.parse(response.body) if response.body
    raise developer_portal_data['error_msg'].to_s if developer_portal_data
    raise 'failed to get developer portal data'
  end

  developer_portal_data = JSON.parse(response.body)

  unless developer_portal_data['error_msg'].to_s.empty?
    log_debug('')
    log_debug('failed to get developer portal data')
    log_debug("status: #{response.code}")
    log_debug("body: #{response.body}")
    raise developer_portal_data['error_msg'].to_s
  end

  user_name = developer_portal_data['apple_id']
  password = developer_portal_data['password']
  tfa_session = developer_portal_data['session_cookies']
  devices = developer_portal_data['test_devices']

  log_debug('')
  log_debug("user_name: #{user_name}")
  log_debug("password: #{password}")
  log_debug("tfa_session: #{tfa_session}")
  log_debug("devices: #{devices}")

  # Spaceship auth
  session = convert_tfa_cookies(tfa_session)
  log_debug('')
  log_debug("session: #{session}")

  developer_portal_authentication(user_name, password, session, team_id)

  #

  exit 1
rescue => ex
  puts
  log_error(ex.to_s + "\n" + ex.backtrace.join("\n"))
  exit 1
end

username = ENV['apple_developer_portal_user']
password = ENV['apple_developer_portal_password']
session = ENV['apple_developer_portal_session']
team_id = ENV['apple_developer_portal_team_id']

project_path = ENV['project_path']
development_certificate_path = ENV['development_certificate_path']
development_certificate_passphrase = ENV['development_certificate_passphrase']
distributon_type = ENV['distributon_type']
distribution_certificate_path = ENV['distribution_certificate_path']
distribution_certificate_passphrase = ENV['distribution_certificate_passphrase']
distributon_type = ENV['distributon_type']

puts
log_info('Params')
log_input('username', username)
log_secret_input('password', password)
log_secret_input('session', session)
log_input('team_id', team_id)

log_input('project_path', project_path)
log_input('development_certificate_path', development_certificate_path)
log_secret_input('development_certificate_passphrase', development_certificate_passphrase)
log_input('distributon_type', distributon_type)
log_input('distribution_certificate_path', distribution_certificate_path)
log_secret_input('distribution_certificate_passphrase', distribution_certificate_passphrase)

if development_certificate_path.start_with?('file://')
  development_certificate_path = development_certificate_path.sub('file://', '')
else
  tmp_dir = Dir.mktmpdir
  certificate_path = File.join(tmp_dir, 'DevelopmentCertificate.p12')
  raise 'failed to download certificate' unless system("wget -q -O \"#{certificate_path}\" \"#{development_certificate_path}\"")
  development_certificate_path = certificate_path
end

if distribution_certificate_path.start_with?('file://')
  distribution_certificate_path = distribution_certificate_path.sub('file://', '')
else
  tmp_dir = Dir.mktmpdir
  certificate_path = File.join(tmp_dir, 'DistributionCertificate.p12')
  raise 'failed to download certificate' unless system("wget -q -O \"#{certificate_path}\" \"#{distribution_certificate_path}\"")
  distribution_certificate_path = certificate_path
end

ditribution_provisioning_profile_type = nil
case distributon_type
when 'app-store'
  ditribution_provisioning_profile_type = SupportedProvisionigProfileTypes::APP_STORE
when 'ad-hoc'
  ditribution_provisioning_profile_type = SupportedProvisionigProfileTypes::AD_HOC
when 'enterprise'
  ditribution_provisioning_profile_type = SupportedProvisionigProfileTypes::IN_HOUSE
when 'development'
  ditribution_provisioning_profile_type = SupportedProvisionigProfileTypes::DEVELOPMENT
when 'none'
  ditribution_provisioning_profile_type = nil
else
  log_error("invalid distribution type: #{distributon_type}")
end

# Authentication
puts
log_info('Authentication')
developer_portal_authentication(username, password, session, team_id)
log_done("authenticated: #{username}")

# Analyze project
bundle_id_code_sing_info_map = {}

project_bundle_ids_map = get_project_bundle_ids(project_path)
project_bundle_ids_map.each do |path, bundle_ids|
  puts
  log_info("Analyzing project: #{path}")

  bundle_ids.each do |bundle_id|
    log_details("analyzing target with bundle id: #{bundle_id}")

    app = ensure_app(bundle_id)
    update_app_services(path, app)

    certificate = find_portal_certificate(development_certificate_path, development_certificate_passphrase)
    profile = ensure_provisioning_profile(app, certificate, SupportedProvisionigProfileTypes::DEVELOPMENT)

    development_code_sign_info_map = {
      certificate: certificate,
      certificate_path: development_certificate_path,
      certificate_passphrase: development_certificate_passphrase,
      profile: profile
    }

    bundle_id_code_sing_info_map[bundle_id] = {
      app: app,
      development: development_code_sign_info_map
    }

    next unless ditribution_provisioning_profile_type

    certificate = find_portal_certificate(distribution_certificate_path, distribution_certificate_passphrase)
    profile = ensure_provisioning_profile(app, certificate, ditribution_provisioning_profile_type)

    distribution_code_sign_info_map = {
      certificate_path: distribution_certificate_path,
      certificate_passphrase: distribution_certificate_passphrase,
      certificate: certificate,
      profile: profile
    }

    bundle_id_code_sing_info_map[bundle_id][:distribution] = distribution_code_sign_info_map
  end
end

force_code_sign_properties(project_path, bundle_id_code_sing_info_map, team_id)

certificate_passphrase_map = {}
provisioning_profile_path_map = {}
tmp_dir = Dir.mktmpdir

bundle_id_code_sing_info_map.each do |bundle_id, code_sign_info|
  puts
  log_info("signing: #{bundle_id}")

  log_details("app: #{code_sign_info[:app].name}")

  log_details("certificate: #{code_sign_info[:development][:certificate].name}")
  certificate_path = code_sign_info[:development][:certificate_path]
  passphrase = code_sign_info[:development][:certificate_passphrase]
  certificate_passphrase_map[certificate_path] = passphrase

  profile = code_sign_info[:development][:profile]
  log_details("profile: #{code_sign_info[:development][:profile].name}")
  profile_path = download_profile(profile, tmp_dir)
  provisioning_profile_path_map['file://' + profile_path] = true

  next unless ditribution_provisioning_profile_type

  log_details("certificate: #{code_sign_info[:distribution][:certificate].name}")
  certificate_path = code_sign_info[:distribution][:certificate_path]
  passphrase = code_sign_info[:distribution][:certificate_passphrase]
  certificate_passphrase_map[certificate_path] = passphrase

  profile = code_sign_info[:distribution][:profile]
  log_details("profile: #{code_sign_info[:distribution][:profile].name}")
  profile_path = download_profile(profile, tmp_dir)
  provisioning_profile_path_map['file://' + profile_path] = true
end

certificate_paths = []
certificate_passphrases = []

certificate_passphrase_map.each do |certificate, passphrase|
  certificate_paths.push('file://' + certificate)
  certificate_passphrases.push(passphrase)
end

certificate_path_list = certificate_paths.join('|')
certificate_passphrase_list = certificate_passphrases.join('|')
provisioning_profile_path_list = provisioning_profile_path_map.keys.join('|')

raise 'failed to export CERTIFICATE_PATH_LIST' unless system("envman add --key CERTIFICATE_PATH_LIST --value \"#{certificate_path_list}\"")
raise 'failed to export CERTIFICATE_PASSPHRASE_LIST' unless system("envman add --key CERTIFICATE_PASSPHRASE_LIST --value \"#{certificate_passphrase_list}\"")
raise 'failed to export PROVISIONING_PROFILE_PATH_LIST' unless system("envman add --key PROVISIONING_PROFILE_PATH_LIST --value \"#{provisioning_profile_path_list}\"")

exit(0)
