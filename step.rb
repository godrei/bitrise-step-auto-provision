require 'net/http'

require 'fastlane'
require 'spaceship'

require_relative 'auto-provision/analyzer'
require_relative 'auto-provision/authenticator'
require_relative 'auto-provision/downloader'
require_relative 'auto-provision/generator'
require_relative 'auto-provision/log'

DEBUG_LOG = true

# Params
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

puts
log_info('Params')
puts "username: #{username}"
puts "password: #{password}"
puts "session: #{session}"
puts "team_id: #{team_id}"
puts
puts "project_path: #{project_path}"
puts
puts "development_certificate_path: #{development_certificate_path}"
puts "development_certificate_passphrase: #{development_certificate_passphrase}"
puts
puts "distributon_type: #{distributon_type}"
puts "distribution_certificate_path: #{distribution_certificate_path}"
puts "distribution_certificate_passphrase: #{distribution_certificate_passphrase}"

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
  log_error('invalid distribution type: #{distributon_type}')
end

# Authentication
puts
log_info('Authentication')
developer_portal_sign_in(username, password, session, team_id)
log_done("authenticated: #{username}")

# Analyze project
force_manual_code_sign(project_path)

bundle_id_code_sing_info_map = {}

project_bundle_id_entitlements_map = get_project_bundle_id_entitlements_map(project_path)
project_bundle_id_entitlements_map.each do |path, bundle_id_entitlements_map|
  puts
  log_info("Analyzing project: #{path}")

  bundle_id_entitlements_map.each do |bundle_id, entitlements_path|
    log_details("  analyzing target with bundle id: #{bundle_id}")
    log_details("  entitlements: #{entitlements_path}") unless entitlements_path.to_s.empty?

    app = ensure_app(bundle_id, entitlements_path)
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

apply_code_signing(project_path, bundle_id_code_sing_info_map, team_id)

certificate_passphrase_map = {}
provisioning_profile_path_map = {}
tmp_dir = Dir.mktmpdir

bundle_id_code_sing_info_map.each do |bundle_id, code_sign_info|
  puts
  log_info("signing: #{bundle_id}")

  log_details("  app: #{code_sign_info[:app].name}")

  log_details("  certificate: #{code_sign_info[:development][:certificate].name}")
  certificate_path = code_sign_info[:development][:certificate_path]
  passphrase = code_sign_info[:development][:certificate_passphrase]
  certificate_passphrase_map[certificate_path] = passphrase

  profile = code_sign_info[:development][:profile]
  log_details("  profile: #{code_sign_info[:development][:profile].name}")
  profile_path = download_profile(profile, tmp_dir)
  provisioning_profile_path_map['file://' + profile_path] = true

  next unless ditribution_provisioning_profile_type

  log_details("  certificate: #{code_sign_info[:distribution][:certificate].name}")
  certificate_path = code_sign_info[:distribution][:certificate_path]
  passphrase = code_sign_info[:distribution][:certificate_passphrase]
  certificate_passphrase_map[certificate_path] = passphrase

  profile = code_sign_info[:distribution][:profile]
  log_details("  profile: #{code_sign_info[:distribution][:profile].name}")
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
