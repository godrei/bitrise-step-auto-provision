require 'spaceship'
require 'fastlane'
require 'net/http'

require_relative 'auto-provision/log'
require_relative 'auto-provision/authenticator'
require_relative 'auto-provision/analyzer'
require_relative 'auto-provision/generator'
require_relative 'auto-provision/downloader'

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
  path = File.join(tmp_dir, 'DevelopmentCertificate.p12')
  raise 'failed to download certificate' unless system("wget -O #{path} #{development_certificate_path}")
  development_certificate_path = path
end

if distribution_certificate_path.start_with?('file://')
  distribution_certificate_path = distribution_certificate_path.sub('file://', '')
else
  tmp_dir = Dir.mktmpdir
  path = File.join(tmp_dir, 'DistributionCertificate.p12')
  raise 'failed to download certificate' unless system("wget -O #{path} #{distribution_certificate_path}")
  distribution_certificate_path = path
end

# Authentication
puts
log_info('Authentication')
developer_portal_sign_in(username, password, session, team_id)
log_done("authenticated: #{username}")

# Analyze project
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

bundle_id_code_sing_info_map = {}

wildcard_app = ensure_wildcard_app

project_bundle_id_entitlements_map = get_project_bundle_id_entitlements_map(project_path)
project_bundle_id_entitlements_map.each do |path, bundle_id_entitlements_map|
  puts
  log_info("Analyzing project: #{path}")

  bundle_id_entitlements_map.each do |bundle_id, entitlements_path|
    log_details("  analyzing target with bundle id: #{bundle_id}")
    log_details("  entitlements: #{entitlements_path}") unless entitlements_path.to_s.empty?

    app = ensure_app(bundle_id, entitlements_path)
    development_portal_certificate = find_portal_certificate(development_certificate_path, development_certificate_passphrase)
    development_provisioning_profile = ensure_provisioning_profile(app, development_portal_certificate, SupportedProvisionigProfileTypes::DEVELOPMENT)

    development_code_sign_info_map = {
      development_certificate_path: development_certificate_path,
      development_certificate_passphrase: development_certificate_passphrase,
      development_portal_certificate: development_portal_certificate,
      development_provisioning_profile: development_provisioning_profile
    }

    bundle_id_code_sing_info_map[bundle_id] = {
      wildcard_app: wildcard_app,
      app: app,
      development: development_code_sign_info_map
    }

    unless ditribution_provisioning_profile_type.nil?
      distribution_portal_certificate = find_portal_certificate(distribution_certificate_path, distribution_certificate_passphrase)
      distribution_provisioning_profile = ensure_provisioning_profile(app, distribution_portal_certificate, ditribution_provisioning_profile_type)

      distribution_code_sign_info_map = {
        distribution_certificate_path: distribution_certificate_path,
        distribution_certificate_passphrase: distribution_certificate_passphrase,
        distribution_portal_certificate: distribution_portal_certificate,
        distribution_provisioning_profile: distribution_provisioning_profile
      }

      bundle_id_code_sing_info_map[bundle_id][:distribution] = distribution_code_sign_info_map
    end
  end
end

certificate_passphrase_map = {}
provisioning_profile_path_map = {}
tmp_dir = Dir.mktmpdir

bundle_id_code_sing_info_map.each do |bundle_id, code_sign_info|
  puts
  log_info("signing: #{bundle_id}")

  log_details("  app: #{code_sign_info[:app].name}")
  log_details("  wildcard_app: #{code_sign_info[:wildcard_app].name}")

  log_details("  development_portal_certificate: #{code_sign_info[:development][:development_portal_certificate].name}")
  certificate = code_sign_info[:development][:development_certificate_path]
  passphrase = code_sign_info[:development][:development_certificate_passphrase]
  certificate_passphrase_map[certificate] = passphrase

  profile = code_sign_info[:development][:development_provisioning_profile]
  log_details("  development_provisioning_profile: #{code_sign_info[:development][:development_provisioning_profile].name}")
  profile_path = download_profile(profile, tmp_dir)
  provisioning_profile_path_map[profile_path] = true

  unless ditribution_provisioning_profile_type.nil?
    log_details("  distribution_portal_certificate: #{code_sign_info[:distribution][:distribution_portal_certificate].name}")
    certificate = code_sign_info[:distribution][:distribution_certificate_path]
    passphrase = code_sign_info[:distribution][:distribution_certificate_passphrase]
    certificate_passphrase_map[certificate] = passphrase

    profile = code_sign_info[:distribution][:distribution_provisioning_profile]
    log_details("  distribution_provisioning_profile: #{code_sign_info[:distribution][:distribution_provisioning_profile].name}")
    profile_path = download_profile(profile, tmp_dir)
    provisioning_profile_path_map[profile_path] = true
  end
end

certificate_paths = []
certificate_passphrases = []

certificate_passphrase_map.each do |certificate, passphrase|
  certificate_paths.push(certificate)
  certificate_passphrases.push(passphrase)
end

certificate_path_list = certificate_paths.join('|')
certificate_passphrase_list = certificate_passphrases.join('|')
provisioning_profile_path_list = provisioning_profile_path_map.keys.join('|')

raise 'failed to export CERTIFICATE_PATH_LIST' unless system("envman add --key CERTIFICATE_PATH_LIST --value \"#{certificate_path_list}\"")
raise 'failed to export CERTIFICATE_PASSPHRASE_LIST' unless system("envman add --key CERTIFICATE_PASSPHRASE_LIST --value \"#{certificate_passphrase_list}\"")
raise 'failed to export PROVISIONING_PROFILE_PATH_LIST' unless system("envman add --key PROVISIONING_PROFILE_PATH_LIST --value \"#{provisioning_profile_path_list}\"")

exit(0)
