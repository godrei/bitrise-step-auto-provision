require 'openssl'
require 'fastlane'

def ensure_app(bundle_id)
  app = Spaceship::Portal.app.find(bundle_id)
  if app.nil?
    normalized_bundle_id = bundle_id.tr('.', ' ')
    log_debug("generating app with bundle id (#{bundle_id})")
    app = Spaceship::Portal.app.create!(bundle_id: bundle_id, name: "Bitrise - (#{normalized_bundle_id})")
  else
    log_debug("app with bundle id (#{bundle_id}) already exist")
  end

  raise "failed to ensure app with bundle id: #{bundle_id}" unless app

  app
end

def certificate_matches(certificate1, certificate2)
  certificate1.serial == certificate2.serial
end

def find_development_portal_certificate(local_certificate_path, local_certificate_passphrase)
  p12 = OpenSSL::PKCS12.new(File.read(local_certificate_path), local_certificate_passphrase)
  local_certificate = p12.certificate

  portal_development_certificates = Spaceship::Portal.certificate.development.all
  log_debug('no development certificate belongs to the account') if portal_development_certificates.to_a.empty?
  portal_development_certificates.each do |cert|
    portal_certificate = cert.download
    return cert if certificate_matches(local_certificate, portal_certificate)
  end

  nil
end

def find_production_portal_certificate(local_certificate_path, local_certificate_passphrase)
  p12 = OpenSSL::PKCS12.new(File.read(local_certificate_path), local_certificate_passphrase)
  local_certificate = p12.certificate

  portal_production_certificates = Spaceship::Portal.certificate.production.all
  log_debug('no production certificate belongs to the account') if portal_production_certificates.to_a.empty?
  portal_production_certificates.each do |cert|
    portal_certificate = cert.download
    return cert if certificate_matches(local_certificate, portal_certificate)
  end

  nil
end

def ensure_test_devices(device_infos)
  test_devices = []

  device_infos.each do |device_info|
    uuid = device_info['device_identifier']
    name = device_info['title']

    device = Spaceship::Portal.device.find_by_udid(uuid, include_disabled: true)
    if device.nil?
      device = Spaceship::Portal.device.create!(name: name, udid: uuid)
    else
      device.enable!
    end

    raise 'failed to find or create device' unless device

    test_devices.push(device)
  end

  test_devices
end

def find_or_create_profile(certificate, app, profile_helper, test_devices)
  # find profile by bundle id
  profiles = profile_helper.find_by_bundle_id(app.bundle_id)
  if !profiles.to_a.empty? && profile_helper.is_a?(Spaceship::Portal.AppStore)
    profiles = profiles.find_all { |current| !current.is_adhoc? }
  elsif !profiles.to_a.empty? && profile_helper.is_a?(Spaceship::Portal.AdHoc)
    profiles = profiles.find_all(&:is_adhoc?)
  end

  # create profile if not exist
  profile = nil
  if profiles.to_a.empty?
    profile = profile_helper.create!(bundle_id: app.bundle_id, certificate: certificate, name: "Bitrise Development - (#{app.bundle_id})")
  else
    if profiles.count > 1
      log_warning("multiple #{profile_helper.class.name} provisionig profiles found for bundle id (#{app.bundle_id}), using first:")
      profiles.each_with_index { |prof, index| puts "#{index}, #{prof}" }
    else
      log_debug("#{profile_helper.class.name} profile for bundle id (#{app.bundle_id}) already exist")
    end

    profile = profiles.first
    profile.repair!

    # ensure certificate is included
    certificate_included = false

    certificates = profile.certificates
    certificates.each do |cert|
      if cert.id == certificate.id
        certificate_included = true
        break
      end
    end

    certificates.push(certificate) unless is_included
    profile.certificates = certificates
  end

  raise 'failed to find or create profile' unless profile

  # register test devices
  if profile_helper.is_a?(Spaceship::Portal.Development) || profile_helper.is_a?(Spaceship::Portal.AdHoc)
    profile.devices.each do |device|
      is_registered_on_bitrise = false
      test_devices.each do |test_device|
        if test_device.uuid == device.uuid
          is_registered_on_bitrise = true
          break
        end
      end

      test_devices.push(device) unless is_registered_on_bitrise
    end
    profile.devices = test_devices
    profile.update!
  end

  profile
end

def ensure_provisioning_profile(certificate, app, profile_type, test_devices)
  profile = nil

  case profile_type
  when SupportedProvisionigProfileTypes::DEVELOPMENT
    profile = find_or_create_profile(certificate, app, Spaceship::Portal.provisioning_profile.development, test_devices)
  when SupportedProvisionigProfileTypes::APP_STORE
    profile = find_or_create_profile(certificate, app, Spaceship::Portal.provisioning_profile.app_store, test_devices)
  when SupportedProvisionigProfileTypes::AD_HOC
    profile = find_or_create_profile(certificate, app, Spaceship::Portal.provisioning_profile.ad_hoc, test_devices)
  when SupportedProvisionigProfileTypes::IN_HOUSE
    profile = find_or_create_profile(certificate, app, Spaceship::Portal.provisioning_profile.in_house, test_devices)
  end

  raise 'failed to ensure provisioning profile' unless profile
  profile
end
