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

DEBUG_LOG = true

# Params
class Params
  attr_accessor :build_url
  attr_accessor :build_api_token
  attr_accessor :team_id
  attr_accessor :certificate_urls
  attr_accessor :passphrases
  attr_accessor :distributon_type
  attr_accessor :project_path

  def initialize
    @build_url = ENV['build_url'] || ''
    @build_api_token = ENV['build_api_token'] || ''
    @team_id = ENV['team_id'] || ''
    @certificate_urls = ENV['certificate_urls'] || ''
    @passphrases = ENV['passphrases'] || ''
    @distributon_type = ENV['distributon_type'] || ''
    @project_path = ENV['project_path'] || ''
  end

  def print
    log_info('Params:')
    log_details("build_url: #{@build_url}")
    log_details("build_api_token: #{@build_api_token}")
    log_details("team_id: #{@team_id}")
    log_details("certificate_urls: #{@certificate_urls}")
    log_details("passphrases: #{@passphrases}")
    log_details("distributon_type: #{@distributon_type}")
    log_details("project_path: #{@project_path}")
  end

  def validate
    raise 'missing: build_url' if @build_url.empty?
    raise 'missing: build_api_token' if @build_api_token.empty?
    raise 'missing: team_id' if @team_id.empty?
    raise 'missing: certificate_urls' if @certificate_urls.empty?
    raise 'missing: distributon_type' if @distributon_type.empty?
    raise 'missing: project_path' if @project_path.empty?
  end
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
  ###

  # Download certificates and with passphrases
  certificate_urls = split_pipe_separated_list(params.certificate_urls).reject(&:empty?)
  raise 'no certificates provider' if certificate_urls.to_a.empty?

  passphrases = split_pipe_separated_list(params.passphrases)
  raise "certificates count (#{certificate_urls.length}) and passphrases count (#{passphrases.length}) should match" unless certificate_urls.length == passphrases.length

  certificate_passphrase_map = {}
  certificate_urls.each_with_index do |url, idx|
    path = download_to_tmp_file(url, "Certrificate#{idx}.p12")
    passphrase = passphrases[idx]
    certificate_passphrase_map[path] = passphrase
  end
  log_debug("\ncertificate_passphrase_map: #{certificate_passphrase_map}")
  ###

  # Developer Portal authentication
  portal_data = get_developer_portal_data(params.build_url, params.build_api_token)
  portal_data.print if DEBUG_LOG
  portal_data.validate

  session = convert_tfa_cookies(portal_data.session_cookies)
  log_debug("\nsession: #{session}")

  developer_portal_authentication(portal_data.apple_id, portal_data.password, session, params.team_id)
  log_done("\ndeveloper portal authenticated")
  ###

  # Find certificates on Developer Portal
  path_development_certificate_map = {}
  path_development_certificate_passphrase_map = {}

  path_production_certificate_map = {}
  path_production_certificate_passphrase_map = {}

  certificate_passphrase_map.each do |certificate_path, passphrase|
    log_debug("searching for certificate (#{certificate_path}) with passphrase: (#{passphrase})")

    portal_certificate = find_development_portal_certificate(certificate_path, passphrase)
    if portal_certificate
      log_done("\nportal development certificate found: #{portal_certificate.name}")
      log_done("team: #{portal_certificate.owner_name} (#{portal_certificate.owner_id})")
      raise 'multiple development certificate provided: step can handle only one development (and only one production) certificate' if path_development_certificate_map[certificate_path]

      path_development_certificate_map[certificate_path] = portal_certificate
      path_development_certificate_passphrase_map[certificate_path] = passphrase
    end

    portal_certificate = find_production_portal_certificate(certificate_path, passphrase)
    next unless portal_certificate

    log_done("\nportal prodcution certificate found: #{portal_certificate.name}")
    log_done("team: #{portal_certificate.owner_name} (#{portal_certificate.owner_id})")
    raise 'multiple production certificate provided: step can handle only one production (and only one development) certificate' if path_production_certificate_map[certificate_path]

    path_production_certificate_map[certificate_path] = portal_certificate
    path_production_certificate_passphrase_map[certificate_path] = passphrase
  end
  raise 'no development nor production certificate identified on development portal' if path_development_certificate_map.empty? && path_production_certificate_map.empty?
  ###

  # Ensure test devices
  test_devices = ensure_test_devices(portal_data.test_devices)
  ###

  # Ensure Profiles
  project_helper = ProjectHelper.new(params.project_path)
  project_target_bundle_id = project_helper.project_target_bundle_id_map
  project_target_entitlements = project_helper.project_target_entitlements_map

  log_debug("\nproject_target_bundle_id: #{JSON.pretty_generate(project_target_bundle_id)}")
  log_debug("\nproject_target_entitlements: #{JSON.pretty_generate(project_target_entitlements)}")

  target_development_profile_map = {}
  target_development_profile_path_map = {}

  target_production_profile_map = {}
  target_production_profile_path_map = {}

  project_target_bundle_id.each do |path, target_bundle_id|
    target_entitlements = project_target_entitlements[path]

    puts
    log_info("analyzing project: #{path}")

    target_bundle_id.each do |target, bundle_id|
      entitlements = target_entitlements[target]

      log_details("analyzing target with bundle id: #{bundle_id}")

      app = ensure_app(bundle_id)
      app = sync_app_services(app, entitlements)

      development_portal_certificate = path_development_certificate_map.values[0] unless path_development_certificate_map.empty?
      if development_portal_certificate
        profile = ensure_provisioning_profile(development_portal_certificate, app, 'development', test_devices)
        target_development_profile_map[target] = profile

        log_details("using development profile: #{profile.name}")
        profile_path = download_profile(profile)
        target_development_profile_path_map[target] = profile_path
      end

      next if params.distributon_type == 'development'

      production_portal_certificate = path_production_certificate_map.values[0] unless path_production_certificate_map.empty?
      next unless production_portal_certificate

      profile = ensure_provisioning_profile(production_portal_certificate, app, params.distributon_type, test_devices)
      target_production_profile_map[target] = profile

      log_details("using #{params.distributon_type} profile: #{profile.name}")
      profile_path = download_profile(profile)
      target_production_profile_path_map[target] = profile_path
    end
  end
  ###

  # Force code sign setting in project
  project_target_bundle_id.each do |path, target_bundle_id|
    target_bundle_id.each_key do |target|
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

      team_id = certificate.owner_id
      code_sign_identity = certificate.name
      provisioning_profile_uuid = profile.uuid

      project_helper.force_code_sign_properties(path, target, team_id, code_sign_identity, provisioning_profile_uuid)
    end
  end
  ###

  # Export output
  certificate_paths = path_development_certificate_map.keys.concat(path_production_certificate_map.keys).reject(&:empty?).join('|')
  raise 'failed to export BITRISE_CERTIFICATE_URL' unless system("envman add --key BITRISE_CERTIFICATE_URL --value \"#{certificate_paths}\"")

  certificate_passphrases = path_development_certificate_passphrase_map.values.concat(path_production_certificate_passphrase_map.values).reject(&:empty?).join('|')
  raise 'failed to export BITRISE_CERTIFICATE_PASSPHRASE' unless system("envman add --key BITRISE_CERTIFICATE_PASSPHRASE --value \"#{certificate_passphrases}\"")

  profile_paths = target_development_profile_path_map.values.concat(target_production_profile_path_map.values).reject(&:empty?).join('|')
  raise 'failed to export BITRISE_PROVISION_URL' unless system("envman add --key BITRISE_PROVISION_URL --value \"#{profile_paths}\"")
  ###
rescue => ex
  puts
  log_error(ex.to_s + "\n" + ex.backtrace.join("\n"))
  exit 1
end
