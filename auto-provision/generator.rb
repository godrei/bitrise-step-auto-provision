require 'openssl'
require 'fastlane'
require 'spaceship'

def ensure_app(bundle_id)
  app = Spaceship::Portal.app.find(bundle_id)
  if app.nil?
    normalized_bundle_id = bundle_id.tr('.', ' ')
    log_debug("generating app with bundle id (#{bundle_id})")
    app = Spaceship::Portal.app.create!(bundle_id: bundle_id, name: "Bitrise - (#{normalized_bundle_id})")
  end

  raise "failed to ensure app with bundle id: #{bundle_id}" unless app

  app
end

def certificate_matches(certificate1, certificate2)
  return false unless certificate1.subject == certificate2.subject
  return false unless certificate1.issuer == certificate2.issuer
  return false unless certificate1.serial == certificate2.serial
  true
end

def find_portal_certificate(local_certificate_path, local_certificate_passphrase)
  p12 = OpenSSL::PKCS12.new(File.read(local_certificate_path), local_certificate_passphrase)
  local_certificate = p12.certificate

  portal_development_certificates = Spaceship::Portal.certificate.development.all
  log_debug('no development certificate belongs to the account') if portal_development_certificates.to_a.empty?
  portal_development_certificates.each do |cert|
    portal_certificate = cert.download
    return cert if certificate_matches(local_certificate, portal_certificate)
  end

  portal_production_certificates = Spaceship::Portal.certificate.production.all
  log_debug('no production certificate belongs to the account') if portal_production_certificates.to_a.empty?
  portal_production_certificates.each do |cert|
    portal_certificate = cert.download
    return cert if certificate_matches(local_certificate, portal_certificate)
  end

  raise 'failed to find portal certificate'
end

def ensure_provisioning_profile(app, certificate, profile_type)
  profile = nil

  case profile_type
  when SupportedProvisionigProfileTypes::DEVELOPMENT
    profiles = Spaceship::Portal.provisioning_profile.development.find_by_bundle_id(app.bundle_id)
    if profiles.to_a.empty?
      log_warning("no development provisioning profile found for bundle id: #{app.bundle_id}, generating ...")

      profile = Spaceship::Portal.provisioning_profile.development.create!(bundle_id: app.bundle_id, certificate: certificate, name: "Bitrise Development - (#{app.bundle_id})")
    else
      if profiles.count > 1
        log_warning('multiple development provisionig profile found, using first:')
        profiles.each_with_index { |prof, index| puts "#{index}, #{prof}" }
      end

      profile = profiles.first
      profile = profile.repair!
    end
  when SupportedProvisionigProfileTypes::APP_STORE
    # Both app_store.all and ad_hoc.all return the same
    # This is the case since September 2016, since the API has changed
    # and there is no fast way to get the type when fetching the profiles
    profiles_appstore_adhoc = Spaceship::Portal.provisioning_profile.app_store.find_by_bundle_id(app.bundle_id)
    # Distinguish between App Store and Ad Hoc profiles
    profiles = profiles_appstore_adhoc.find_all { |current| !current.is_adhoc? }

    if profiles.to_a.empty?
      log_warning("no app store provisioning profile found for bundle id: #{app.bundle_id}, generating ...")

      profile = Spaceship::Portal.provisioning_profile.app_store.create!(bundle_id: app.bundle_id, certificate: certificate, name: "Bitrise App Store - (#{app.bundle_id})")
    else
      if profiles.count > 1
        log_warning('multiple app store provisionig profile found, using first:')
        profiles.each_with_index { |prof, index| puts "#{index}, #{prof}" }
      end

      profile = profiles.first
      profile = profile.repair!
    end
  when SupportedProvisionigProfileTypes::AD_HOC
    # Both app_store.all and ad_hoc.all return the same
    # This is the case since September 2016, since the API has changed
    # and there is no fast way to get the type when fetching the profiles
    profiles_appstore_adhoc = Spaceship::Portal.provisioning_profile.ad_hoc.find_by_bundle_id(app.bundle_id)
    # Distinguish between App Store and Ad Hoc profiles
    profiles = profiles_appstore_adhoc.find_all { |current| current.is_adhoc? }

    if profiles.to_a.empty?
      log_warning("no ad hoc provisioning profile found for bundle id: #{app.bundle_id}, generating ...")

      profile = Spaceship::Portal.provisioning_profile.ad_hoc.create!(bundle_id: app.bundle_id, certificate: certificate, name: "Bitrise Ad Hoc - (#{app.bundle_id})")
    else
      if profiles.count > 1
        log_warning('multiple ad hoc provisionig profile found, using first:')
        profiles.each_with_index { |prof, index| puts "#{index}, #{prof}" }
      end

      profile = profiles.first
      profile = profile.repair!
    end
  when SupportedProvisionigProfileTypes::IN_HOUSE
    profiles = Spaceship::Portal.provisioning_profile.in_house.find_by_bundle_id(app.bundle_id)
    if profiles.to_a.empty?
      log_warning("no enterprise provisioning profile found for bundle id: #{app.bundle_id}, generating ...")

      profile = Spaceship::Portal.provisioning_profile.in_house.create!(bundle_id: app.bundle_id, certificate: certificate, name: "Bitrise Enterprise - (#{app.bundle_id})")
    else
      if profiles.count > 1
        log_warning('multiple enterprise provisionig profile found, using first:')
        profiles.each_with_index { |prof, index| puts "#{index}, #{prof}" }
      end

      profile = profiles.first
      profile = profile.repair!
    end
  end

  raise 'failed to ensure provisioning profile' unless profile

  profile
end
