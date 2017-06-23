require 'spaceship'
require 'fastlane'
require 'openssl'

module SupportedCertificateTypes
  DEVELOPMENT = 1
  PRODUCTION = 2
end

module SupportedProvisionigProfileTypes
  DEVELOPMENT = 1
  APP_STORE = 2
  AD_HOC = 3
  IN_HOUSE = 4
end

def ensure_wildcard_app
  app = Spaceship::Portal.app.find('*')
  app = Spaceship::Portal.app.create!(bundle_id: '*', name: "Bitrise App (*)") if app.nil?
  raise "failed to ensure app with wildcard bundle id: *" unless app
  app
end

def ensure_app(bundle_id, entitlements_path = nil)
  app = Spaceship::Portal.app.find(bundle_id)
  if app.nil? && entitlements_path.to_s.empty?
    app = Spaceship::Portal.app.find('*')
  end

  if app.nil?
    if entitlements_path.to_s.empty?
      app = Spaceship::Portal.app.create!(bundle_id: '*', name: 'Bitrise App (*)')
    else
      normalized_bundle_id = bundle_id.tr('.', ' ')
      app = Spaceship::Portal.app.create!(bundle_id: bundle_id, name: "Bitrise App (#{normalized_bundle_id})")
    end
  end

  raise "failed to ensure app with bundle id: #{bundle_id}" unless app

  app = update_app_services(app, entitlements_path) unless entitlements_path.nil?
end

def update_app_services(app, _entitlements_path)
  app
end

def certificate_matches(certificate1, certificate2)
  (certificate1.subject == certificate2.subject &&
  certificate1.issuer == certificate2.issuer &&
  certificate1.serial == certificate2.serial &&
  certificate1.not_before == certificate2.not_before &&
  certificate1.not_after == certificate2.not_after)
end

def find_portal_certificate(local_certificate_path, local_certificate_passphrase)
  p12 = OpenSSL::PKCS12.new(File.read(local_certificate_path), local_certificate_passphrase)
  local_certificate = p12.certificate

  portal_development_certificates = Spaceship::Portal.certificate.development.all
  portal_development_certificates.each do |cert|
    portal_certificate = cert.download
    return cert if certificate_matches(local_certificate, portal_certificate)
  end

  portal_distribution_certificate = Spaceship::Portal.certificate.production.all
  portal_distribution_certificate.each do |cert|
    portal_certificate = cert.download
    return cert if certificate_matches(local_certificate, portal_certificate)
  end

  raise "failed to find portal certificate"
end

def ensure_provisioning_profile(app, certificate, profile_type)
  profile = nil

  case profile_type
  when SupportedProvisionigProfileTypes::DEVELOPMENT
    profiles = Spaceship::Portal.provisioning_profile.development.find_by_bundle_id(app.bundle_id)
    if profiles.to_a.empty?
      log_warning("  no development provisioning profile found for bundle id: #{app.bundle_id}, generating ...")

      profile = Spaceship::Portal.provisioning_profile.development.create!(bundle_id: app.bundle_id, certificate: certificate, name: "Bitrise Development Provisioning Profile (#{app.bundle_id})")
    else
      if profiles.count > 1
        log_warning('  multiple development provisionig profile found, using first:')
        profiles.each_with_index { |prof, index| puts "#{index}, #{prof}" }
      end

      profile = profiles.first
    end
  when SupportedProvisionigProfileTypes::APP_STORE
    profiles = Spaceship::Portal.provisioning_profile.app_store.find_by_bundle_id(app.bundle_id)
    if profiles.to_a.empty?
      log_warning("  no app store provisioning profile found for bundle id: #{app.bundle_id}, generating ...")

      profile = Spaceship::Portal.provisioning_profile.app_store.create!(bundle_id: app.bundle_id, certificate: certificate, name: "Bitrise App Store Provisioning Profile (#{app.bundle_id})")
    else
      if profiles.count > 1
        log_warning('  multiple app store provisionig profile found, using first:')
        profiles.each_with_index { |prof, index| puts "#{index}, #{prof}" }
      end

      profile = profiles.first
    end
  when SupportedProvisionigProfileTypes::AD_HOC
    profiles = Spaceship::Portal.provisioning_profile.ad_hoc.find_by_bundle_id(app.bundle_id)
    if profiles.to_a.empty?
      log_warning("  no ad hoc provisioning profile found for bundle id: #{app.bundle_id}, generating ...")

      profile = Spaceship::Portal.provisioning_profile..ad_hoc.create!(bundle_id: app.bundle_id, certificate: certificate, name: "Bitrise Ad Hoc Provisioning Profile (#{app.bundle_id})")
    else
      if profiles.count > 1
        log_warning('  multiple ad hoc provisionig profile found, using first:')
        profiles.each_with_index { |prof, index| puts "#{index}, #{prof}" }
      end

      profile = profiles.first
    end
  when SupportedProvisionigProfileTypes::IN_HOUSE
    puts 'InHouse'
    profiles = Spaceship::Portal.provisioning_profile.in_house.find_by_bundle_id(app.bundle_id)
    if profiles.to_a.empty?
      log_warning("  no enterprise provisioning profile found for bundle id: #{app.bundle_id}, generating ...")

      profile = Spaceship::Portal.provisioning_profile..in_house.create!(bundle_id: app.bundle_id, certificate: certificate, name: "Bitrise In House Provisioning Profile (#{app.bundle_id})")
    else
      if profiles.count > 1
        log_warning('  multiple enterprise provisionig profile found, using first:')
        profiles.each_with_index { |prof, index| puts "#{index}, #{prof}" }
      end

      profile = profiles.first
    end
  end

  raise "failed to ensure provisioning profile" unless profile

  profile
end
