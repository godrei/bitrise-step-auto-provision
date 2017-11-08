require 'net/http'
require 'uri'
require 'json'

require 'fastlane'

require_relative 'log/log'
require_relative 'project_helper/project_helper'
require_relative 'http_helper/http_helper'
require_relative 'http_helper/portal_data'
require_relative 'auto-provision/authenticator'
require_relative 'auto-provision/generator'
require_relative 'auto-provision/app_services'
require_relative 'keychain/keychain'

# Params
class Params
  attr_accessor :build_url
  attr_accessor :build_api_token
  attr_accessor :team_id
  attr_accessor :certificate_urls
  attr_accessor :passphrases
  attr_accessor :distributon_type
  attr_accessor :project_path
  attr_accessor :keychain_path
  attr_accessor :keychain_password
  attr_accessor :verbose_log

  def initialize
    @build_url = ENV['build_url'] || ''
    @build_api_token = ENV['build_api_token'] || ''
    @team_id = ENV['team_id'] || ''
    @certificate_urls = ENV['certificate_urls'] || ''
    @passphrases = ENV['passphrases'] || ''
    @distributon_type = ENV['distributon_type'] || ''
    @project_path = ENV['project_path'] || ''
    @keychain_path = ENV['keychain_path'] || ''
    @keychain_password = ENV['keychain_password'] || ''
    @verbose_log = ENV['verbose_log'] || ''
  end

  def print
    log_info('Params:')
    log_details("team_id: #{@team_id}")
    log_details("certificate_urls: #{secure_value(@certificate_urls)}")
    log_details("passphrases: #{secure_value(@passphrases)}")
    log_details("distributon_type: #{@distributon_type}")
    log_details("project_path: #{@project_path}")
    log_details("build_url: #{@build_url}")
    log_details("build_api_token: #{secure_value(@build_api_token)}")
    log_details("keychain_path: #{@keychain_path}")
    log_details("keychain_password: #{secure_value(@keychain_password)}")
    log_details("verbose_log: #{@verbose_log}")
  end

  def validate
    raise 'missing: build_url' if @build_url.empty?
    raise 'missing: build_api_token' if @build_api_token.empty?
    raise 'missing: team_id' if @team_id.empty?
    raise 'missing: certificate_urls' if @certificate_urls.empty?
    raise 'missing: distributon_type' if @distributon_type.empty?
    raise 'missing: project_path' if @project_path.empty?
    raise 'missing: keychain_path' if @keychain_path.empty?
    raise 'missing: keychain_password' if @keychain_password.empty?
    raise 'missing: verbose_log' if @verbose_log.empty?
  end
end

def secure_value(value)
  return '' if value.empty?
  '***'
end

def split_pipe_separated_list(list)
  separator_count = list.count('|')
  char_count = list.length

  return [] if char_count.zero?
  return [list] unless list.include?('|')
  return Array.new(separator_count + 1, '') if separator_count == char_count
  list.split('|').map(&:strip)
end

begin
  # Params
  params = Params.new
  params.print
  params.validate

  DEBUG_LOG = (params.verbose_log == 'yes')
  ###

  # Developer Portal authentication
  log_info('Developer Portal authentication')

  portal_data = get_developer_portal_data(params.build_url, params.build_api_token)
  portal_data.validate

  log_debug("session cookie: #{portal_data.session_cookies}\n")
  session = convert_tfa_cookies(portal_data.session_cookies)
  log_debug("converted session cookie: #{session}\n")

  developer_portal_authentication(portal_data.apple_id, portal_data.password, session, params.team_id)

  log_done('authenticated')
  ###

  # Download certificates
  log_info('Downloading Certificates')

  certificate_urls = split_pipe_separated_list(params.certificate_urls).reject(&:empty?)
  raise 'no certificates provider' if certificate_urls.to_a.empty?

  passphrases = split_pipe_separated_list(params.passphrases)
  raise "certificates count (#{certificate_urls.length}) and passphrases count (#{passphrases.length}) should match" unless certificate_urls.length == passphrases.length

  certificate_passphrase_map = {}
  certificate_urls.each_with_index do |url, idx|
    log_debug("downloading certificate ##{idx + 1}")
    path = download_to_tmp_file(url, "Certrificate#{idx}.p12")
    log_debug("certificate path: #{path}")
    passphrase = passphrases[idx]
    certificate_passphrase_map[path] = passphrase
  end
  log_done("#{certificate_passphrase_map.length} certificates downloaded")
  ###

  # Find certificates on Developer Portal
  log_info('Identify Certificates on developer Portal')

  path_development_certificate_map = {}
  path_development_certificate_passphrase_map = {}

  path_production_certificate_map = {}
  path_production_certificate_passphrase_map = {}

  certificate_passphrase_map.each do |certificate_path, passphrase|
    log_debug("searching for Certificates (#{certificate_path})")

    portal_certificate = find_development_portal_certificate(certificate_path, passphrase)
    if portal_certificate
      log_done("development Certificates found: #{portal_certificate.name}")
      raise 'multiple development certificates provided: step can handle only one development (and only one production) certificate' if path_development_certificate_map[certificate_path]

      path_development_certificate_map[certificate_path] = portal_certificate
      path_development_certificate_passphrase_map[certificate_path] = passphrase
    end

    portal_certificate = find_production_portal_certificate(certificate_path, passphrase)
    next unless portal_certificate

    log_done("production Certificates found: #{portal_certificate.name}")
    raise 'multiple production certificates provided: step can handle only one production (and only one development) certificate' if path_production_certificate_map[certificate_path]

    path_production_certificate_map[certificate_path] = portal_certificate
    path_production_certificate_passphrase_map[certificate_path] = passphrase
  end
  raise 'no development nor production certificate identified on development portal' if path_development_certificate_map.empty? && path_production_certificate_map.empty?
  ###

  # Ensure test devices
  log_info('Ensure test devices on Developer Portal')
  test_devices = ensure_test_devices(portal_data.test_devices)
  ###

  # Anlyzing project
  log_info('Anlyzing project')

  project_helper = ProjectHelper.new(params.project_path)

  project_target_bundle_id = project_helper.project_target_bundle_id_map
  raise 'no targets found' if project_target_bundle_id.to_a.empty?

  project_target_entitlements = project_helper.project_target_entitlements_map
  raise 'no targets found' if project_target_entitlements.to_a.empty?
  raise 'analyzer failed' unless project_target_bundle_id.to_a.length == project_target_entitlements.to_a.length

  project_target_bundle_id.each do |project_path, target_bundle_id|
    log_done("project: #{project_path}")

    idx = 0
    target_bundle_id.each do |target, bundle_id|
      idx += 1
      entitlements_count = (project_target_entitlements[project_path][target] || []).length

      log_details("target ##{idx}: #{target} (#{bundle_id}) with #{entitlements_count} services")
    end
  end
  ###

  # Anlyzing project
  log_info('Ensure App IDs and Provisioning Profiles on Developer Portal')

  target_development_profile_map = {}
  target_development_profile_path_map = {}

  target_production_profile_map = {}
  target_production_profile_path_map = {}

  project_target_bundle_id.each do |path, target_bundle_id|
    target_entitlements = project_target_entitlements[path]
    log_details("checking project: #{path}")
    target_bundle_id.each do |target, bundle_id|
      entitlements = target_entitlements[target]
      log_done("checking target: #{target} (#{bundle_id}) with #{entitlements.length} services")

      log_details("Ensure App ID (#{bundle_id}) on Developer Portal")
      app = ensure_app(bundle_id)

      log_details("Sync App ID (#{bundle_id}) Services")
      app = sync_app_services(app, entitlements)

      development_portal_certificate = path_development_certificate_map.values[0] unless path_development_certificate_map.empty?
      if development_portal_certificate
        log_details('Ensure Development Provisioning Profile on Developer Portal')

        profile = ensure_provisioning_profile(development_portal_certificate, app, 'development', test_devices)
        target_development_profile_map[target] = profile

        log_done("downloading development profile: #{profile.name}")
        profile_path = download_profile(profile)
        log_debug("profile path: #{profile_path}")
        target_development_profile_path_map[target] = profile_path
      end

      next if params.distributon_type == 'development'

      production_portal_certificate = path_production_certificate_map.values[0] unless path_production_certificate_map.empty?
      next unless production_portal_certificate

      log_details('Ensure Production Provisioning Profile on Developer Portal')

      profile = ensure_provisioning_profile(production_portal_certificate, app, params.distributon_type, test_devices)
      target_production_profile_map[target] = profile

      log_done("downloading #{params.distributon_type} profile: #{profile.name}")
      profile_path = download_profile(profile)
      log_debug("profile path: #{profile_path}")
      target_production_profile_path_map[target] = profile_path
    end
  end
  ###

  # Apply code sign setting in project
  log_info('Apply code sign setting in project')

  project_target_bundle_id.each do |path, target_bundle_id|
    log_details("checking project: #{path}")
    target_bundle_id.each_key do |target|
      log_done("checking target: #{target} (#{bundle_id})")
      certificate = nil
      profile = nil

      portal_certificate = path_development_certificate_map.values[0] unless path_development_certificate_map.empty?
      if portal_certificate
        portal_profile = target_development_profile_map.values[0] unless target_development_profile_map.empty?

        certificate = portal_certificate
        profile = portal_profile
      else
        portal_certificate = path_production_certificate_map.values[0] unless path_production_certificate_map.empty?
        if portal_certificate
          portal_profile = target_production_profile_map.values[0] unless target_production_profile_map.empty?

          certificate = portal_certificate
          profile = portal_profile
        end
      end


      log_details('CODE_SIGN_STYLE: Manual')
      log_details('ProvisioningStyle: Manual')

      team_id = certificate.owner_id
      log_details("DEVELOPMENT_TEAM: #{team_id}")

      code_sign_identity = certificate.name
      log_details("CODE_SIGN_IDENTITY: #{code_sign_identity}")

      provisioning_profile_uuid = profile.uuid
      log_details("PROVISIONING_PROFILE: #{provisioning_profile_uuid}")

      project_helper.force_code_sign_properties(path, target, team_id, code_sign_identity, provisioning_profile_uuid)

      build_settings = project_helper.xcodebuild_target_build_settings(path, target)
      log_debug('build settings:')
      build_settings.each { |key, value| log_debug("#{key}: #{value}") }
    end
  end
  ###

  # Install certificates
  log_info('Install certificates')

  keychain_helper = KeychainHelper.new(params.keychain_path, params.keychain_password)

  certificate_passphrase_map.each do |path, passphrase|
    keychain_helper.import_certificate(path, passphrase)
  end

  keychain_helper.set_key_partition_list_if_needed
  keychain_helper.set_keychain_settings_default_lock
  keychain_helper.add_to_keychain_search_path
  keychain_helper.set_default_keychain
  keychain_helper.unlock_keychain

  log_done("#{certificate_passphrase_map.length} certificates installed")
  ###
rescue => ex
  puts
  log_error(ex.to_s)
  log_error(ex.backtrace.join("\n").to_s) if DEBUG_LOG
  exit 1
end
