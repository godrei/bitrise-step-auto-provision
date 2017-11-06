require 'net/http'
require 'uri'
require 'json'

require 'fastlane'

require_relative 'log/log'
require_relative 'bitrise/bitrise'
require_relative 'project_helper/project_helper'
require_relative 'file_helper/file_helper'
require_relative 'auto-provision/authenticator'
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

  log_info('authentication Params:')
  log_input('build_url', build_url)
  log_input('build_api_token', build_api_token)
  log_input('team_id', team_id)

  log_info('auto-provision Params:')
  log_input('certificate_urls', certificate_urls)
  log_input('certificate_passphrases', certificate_passphrases)
  log_input('distributon_type', distributon_type)
  log_input('project_path', project_path)

  raise 'missing: build_url' if build_url.to_s.empty?
  raise 'missing: build_api_token' if build_api_token.to_s.empty?
  raise 'missing: team_id' if team_id.to_s.empty?

  raise 'missing: certificate_urls' if certificate_urls.to_s.empty?
  raise 'missing: distributon_type' if distributon_type.to_s.empty?
  raise 'missing: project_path' if project_path.to_s.empty?

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
  ###

  # Download certificates
  certificate_split = []
  if certificate_urls.include?('|')
    split = certificate_urls.split('|')
    certificate_split = split.map(&:strip)
  else
    certificate_split.push(certificate_urls)
  end

  passphrase_split = []
  if certificate_passphrases.include?('|')
    separator_count = certificate_passphrases.count('|')
    if certificate_passphrases.length == separator_count
      passphrase_split = Array.new(separator_count + 1, '')
    else
      split = certificate_passphrases.split('|')
      passphrase_split = split.map(&:strip)
    end
  else
    passphrase_split.push(certificate_passphrases)
  end

  raise "certificates count (#{certificate_split.length}) and passphrases count (#{passphrase_split.length}) should match" unless certificate_split.length == passphrase_split.length

  certificate_passphrase_map = create_certificate_path_passphrase_map(certificate_split, passphrase_split)
  puts "\ncertificate_passphrase_map: #{certificate_passphrase_map}"
  ###

  # Bitrise developer portal data
  developer_portal_data = get_developer_portal_data(build_url, build_api_token)
  user_name = developer_portal_data['apple_id']
  password = developer_portal_data['password']
  tfa_session = developer_portal_data['session_cookies']
  devices = developer_portal_data['test_devices']

  puts("\nuser_name: #{user_name}")
  puts("password: #{password}")
  puts("tfa_session: #{tfa_session}")
  puts("devices: #{devices}")
  ###

  # Spaceship auth
  session = convert_tfa_cookies(tfa_session)
  puts("\nsession: #{session}")

  developer_portal_authentication(user_name, password, session, team_id)
  puts("\nspaceship authenticated")
  ###

  # Generate code sign files
  # Find certificates
  development_portal_certificate = nil
  production_portal_certificate = nil

  code_sign_info = {}
  certificate_passphrase_map.each do |certificate_path, passphrase|
    portal_certificate = find_development_portal_certificate(certificate_path, passphrase)
    if portal_certificate
      puts "\nportal development certificate found: #{portal_certificate.name}"
      raise 'multiple development certificate provided: step can handle only one development (and only one production) certificate' if development_portal_certificate

      development_portal_certificate = portal_certificate

      code_sign_info[:development_certificate] = {
        path: certificate_path,
        certificate: portal_certificate,
        passphrase: passphrase
      }
    end

    portal_certificate = find_production_portal_certificate(certificate_path, passphrase)
    next unless portal_certificate

    puts "\nportal prodcution certificate found: #{portal_certificate.name}"
    raise 'multiple production certificate provided: step can handle only one production (and only one development) certificate' if production_portal_certificate

    production_portal_certificate = portal_certificate

    code_sign_info[:production_certificate] = {
      path: certificate_path,
      certificate: portal_certificate,
      passphrase: passphrase
    }
  end

  raise 'no development nor production certificate identified on development portal' if development_portal_certificate.nil? && production_portal_certificate.nil?

  # Ensure test devices
  test_devices = ensure_test_devices(devices)

  # Ensure Profiles
  project_helper = ProjectHelper.new(project_path)
  project_target_bundle_id = project_helper.project_target_bundle_id_map
  project_target_entitlements = project_helper.project_target_entitlements_map

  puts "\nproject_target_bundle_id: #{JSON.pretty_generate(project_target_bundle_id)}"
  puts "\nproject_target_entitlements: #{JSON.pretty_generate(project_target_entitlements)}"

  project_target_bundle_id.each do |path, target_bundle_id|
    target_entitlements = project_target_entitlements[path]

    puts
    log_info("analyzing project: #{path}")

    target_bundle_id.each do |target, bundle_id|
      entitlements = target_entitlements[target]

      log_details("analyzing target with bundle id: #{bundle_id}")

      app = ensure_app(bundle_id)
      sync_app_services(app, entitlements)

      if development_portal_certificate
        profile = ensure_provisioning_profile(development_portal_certificate, app, SupportedProvisionigProfileTypes::DEVELOPMENT, test_devices)
        puts "using development profile: #{profile.name}"
        profile_path = download_profile(profile)

        projects = code_sign_info[:projects] || {}
        target_info = projects[path] || {}
        info = target_info[target] || {}
        info[:app] = app unless info[:app]
        info[:development_profile] = {
          path: profile_path,
          profile: profile
        }

        target_info[target] = info
        projects[path] = target_info
        code_sign_info[:projects] = projects
      end

      next unless production_portal_certificate

      profile = ensure_provisioning_profile(production_portal_certificate, app, ditribution_provisioning_profile_type, test_devices)
      puts "using #{distributon_type} profile: #{profile.name}"
      profile_path = download_profile(profile)

      projects = code_sign_info[:projects] || {}
      target_info = projects[path] || {}
      info = target_info[target] || {}
      info[:app] = app unless info[:app]
      info[:production_profile] = {
        path: profile_path,
        profile: profile
      }

      target_info[target] = info
      projects[path] = target_info
      code_sign_info[:projects] = projects
    end
  end

  puts("\ncode sign info:\n#{JSON.pretty_generate(code_sign_info)}")

  exit 1
  ###

  # Force code sign setting in project
  project_infos = code_sign_info[:projects]
  project_infos.each do |path, target_info|
    target_info.each do |target, info|
      certificate = nil
      profile = nil

      if code_sign_info[:development_certificate]
        certificate = code_sign_info[:development_certificate][:certificate]
        profile = info[:development_profile][:profile]
      else 
        certificate = code_sign_info[:production_certificate][:certificate]
        profile = info[:production_profile][:profile]
      end

      team_id = certificate.owner_id
      code_sign_identity = certificate.name
      provisioning_profile_uuid = profile.uuid
  
      project_helper.force_code_sign_properties(path, target, team_id, code_sign_identity, provisioning_profile_uuid)
    end
  end
  ###

  # Export output

  ###

  exit 1
rescue => ex
  puts
  log_error(ex.to_s + "\n" + ex.backtrace.join("\n"))
  exit 1
end

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
