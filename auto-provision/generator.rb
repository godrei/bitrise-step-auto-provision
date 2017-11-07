require 'openssl'
require 'fastlane'

def ensure_app(bundle_id)
  app = Spaceship::Portal.app.find(bundle_id)
  if app.nil?
    normalized_bundle_id = bundle_id.tr('.', ' ')
    log_debug("\ngenerating app with bundle id (#{bundle_id})")
    app = Spaceship::Portal.app.create!(bundle_id: bundle_id, name: "Bitrise - (#{normalized_bundle_id})")
  else
    log_debug("\napp with bundle id (#{bundle_id}) already exist")
  end

  raise "failed to find or create app with bundle id: #{bundle_id}" unless app

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

def ensure_test_devices(test_devices)
  updated_portal_devices = []
  portal_devices = Spaceship::Portal.device.all(mac: false, include_disabled: true) || []
  test_devices.each do |test_device|
    registered_test_device = nil

    portal_devices.each do |portal_device|
      next unless portal_device.udid == test_device.uuid

      registered_test_device = portal_device
      log_debug("Test device (#{registered_test_device.name} - #{registered_test_device.udid}) already registered")
      break
    end

    unless registered_test_device
      registered_test_device = Spaceship::Portal.device.create!(name: test_device.name, udid: test_device.uuid)
      log_debug("Created test device (#{registered_test_device.name} - #{registered_test_device.udid})")
    end
    raise 'failed to find or create device' unless registered_test_device

    updated_portal_devices.push(registered_test_device)
  end

  updated_portal_devices
end

def find_profile_by_bundle_id(profiles, bundle_id)
  matching = []
  profiles.each do |profile|
    matching.push(profile) if profile.app.bundle_id == bundle_id
  end

  matching
end

def ensure_profile_certificate(profile, certificate)
  certificate_included = false

  certificates = profile.certificates
  certificates.each do |cert|
    if cert.id == certificate.id
      certificate_included = true
      break
    end
  end

  unless certificate_included
    certificates.push(certificate)
    profile.certificates = certificates
  end

  profile
end

def ensure_profile_devices(profile, devices)
  profile_devices = profile.devices
  updated_devices = [].concat(profile_devices)

  devices.each do |device|
    device_included = false

    profile_devices.each do |profile_device|
      if profile_device.udid == device.udid
        device_included = true
        break
      end
    end

    updated_devices.push(device) unless device_included
  end

  profile.devices = updated_devices
  profile
end

def ensure_provisioning_profile(certificate, app, distributon_type, test_devices)
  profile = nil

  case distributon_type
  when 'development'
    profiles = find_profile_by_bundle_id(Spaceship::Portal.provisioning_profile.development.all, app.bundle_id)
    if profiles.to_a.empty?
      log_warning("no development provisioning profile found for bundle id: #{app.bundle_id}, generating ...")

      profile = Spaceship::Portal.provisioning_profile.development.create!(bundle_id: app.bundle_id, certificate: certificate, name: "Bitrise Development - (#{app.bundle_id})")
    else
      if profiles.count > 1
        log_warning('multiple development provisionig profile found for bundle id, using first:')
        profiles.each_with_index { |prof, index| puts "#{index}, #{prof}" }
      else
        log_debug("development profile for bundle id (#{app.bundle_id}) already exist")
      end

      profile = profiles.first

      # ensure certificate is included
      profile = ensure_profile_certificate(profile, certificate)
    end

    # register test devices
    profile = ensure_profile_devices(profile, test_devices)

    profile = profile.update!
  when 'app-store'
    # Both app_store.all and ad_hoc.all return the same
    # This is the case since September 2016, since the API has changed
    # and there is no fast way to get the type when fetching the profiles
    profiles_appstore_adhoc = find_profile_by_bundle_id(Spaceship::Portal.provisioning_profile.app_store.all, app.bundle_id)
    # Distinguish between App Store and Ad Hoc profiles
    profiles = profiles_appstore_adhoc.find_all { |current| !current.is_adhoc? }

    if profiles.to_a.empty?
      log_warning("no app store provisioning profile found for bundle id: #{app.bundle_id}, generating ...")

      profile = Spaceship::Portal.provisioning_profile.app_store.create!(bundle_id: app.bundle_id, certificate: certificate, name: "Bitrise App Store - (#{app.bundle_id})")
    else
      if profiles.count > 1
        log_warning('multiple app store provisionig profile found, using first:')
        profiles.each_with_index { |prof, index| puts "#{index}, #{prof}" }
      else
        log_debug("app store profile for bundle id (#{app.bundle_id}) already exist")
      end

      profile = profiles.first

      # ensure certificate is included
      profile = ensure_profile_certificate(profile, certificate)

      profile = profile.update!
    end
  when 'ad-hoc'
    # Both app_store.all and ad_hoc.all return the same
    # This is the case since September 2016, since the API has changed
    # and there is no fast way to get the type when fetching the profiles
    profiles_appstore_adhoc = find_profile_by_bundle_id(Spaceship::Portal.provisioning_profile.ad_hoc.all, app.bundle_id)
    # Distinguish between App Store and Ad Hoc profiles
    profiles = profiles_appstore_adhoc.find_all(&:is_adhoc?)

    if profiles.to_a.empty?
      log_warning("no ad hoc provisioning profile found for bundle id: #{app.bundle_id}, generating ...")

      profile = Spaceship::Portal.provisioning_profile.ad_hoc.create!(bundle_id: app.bundle_id, certificate: certificate, name: "Bitrise Ad Hoc - (#{app.bundle_id})")
    else
      if profiles.count > 1
        log_warning('multiple ad hoc provisionig profile found, using first:')
        profiles.each_with_index { |prof, index| puts "#{index}, #{prof}" }
      else
        log_debug("ad hoc profile for bundle id (#{app.bundle_id}) already exist")
      end

      profile = profiles.first

      # ensure certificate is included
      profile = ensure_profile_certificate(profile, certificate)
    end

    # register test devices
    profile = ensure_profile_devices(profile, test_devices)

    profile = profile.update!
  when 'enterprise'
    profiles = find_profile_by_bundle_id(Spaceship::Portal.provisioning_profile.in_house.all, app.bundle_id)
    if profiles.to_a.empty?
      log_warning("no enterprise provisioning profile found for bundle id: #{app.bundle_id}, generating ...")

      profile = Spaceship::Portal.provisioning_profile.in_house.create!(bundle_id: app.bundle_id, certificate: certificate, name: "Bitrise Enterprise - (#{app.bundle_id})")
    else
      if profiles.count > 1
        log_warning('multiple enterprise provisionig profile found, using first:')
        profiles.each_with_index { |prof, index| puts "#{index}, #{prof}" }
      else
        log_debug("enterprise profile for bundle id (#{app.bundle_id}) already exist")
      end

      profile = profiles.first

      # ensure certificate is included
      profile = ensure_profile_certificate(profile, certificate)

      profile = profile.update!
    end
  else
    raise "invalid distribution type provided: #{distributon_type}, available: []"
  end

  raise 'failed to ensure provisioning profile' unless profile

  profile
end
