require 'fastlane'

def sync_app_services(app, entitlements)
  entitlement_on_off_app_service_map = {
    # App Groups
    'com.apple.security.application-groups' => Spaceship::Portal.app_service.app_group,
    # Apple Pay
    'com.apple.developer.in-app-payments' => Spaceship::Portal.app_service.apple_pay,
    # Associated Domains
    'com.apple.developer.associated-domains' => Spaceship::Portal.app_service.associated_domains,
    # HealthKit
    'com.apple.developer.healthkit' => Spaceship::Portal.app_service.health_kit,
    # HomeKit
    'com.apple.developer.homekit' => Spaceship::Portal.app_service.home_kit,
    # Hotspot
    'com.apple.developer.networking.HotspotConfiguration' => Spaceship::Portal.app_service.hotspot,
    # In-App Purchase
    'com.apple.InAppPurchase' => Spaceship::Portal.app_service.in_app_purchase,
    # Inter-App Audio
    'inter-app-audio' => Spaceship::Portal.app_service.inter_app_audio,
    # Multipath
    'com.apple.developer.networking.multipath' => Spaceship::Portal.app_service.multipath,
    # Network Extensions
    'com.apple.developer.networking.networkextension' => Spaceship::Portal.app_service.network_extension,
    # NFC Tag Reading
    'com.apple.developer.nfc.readersession.formats' => Spaceship::Portal.app_service.nfc_tag_reading,
    # Personal VPN
    'com.apple.developer.networking.vpn.api' => Spaceship::Portal.app_service.vpn_configuration,
    # Push Notifications
    'aps-environment' => Spaceship::Portal.app_service.push_notification,
    # SiriKit
    'com.apple.developer.siri' => Spaceship::Portal.app_service.siri_kit,
    # Wallet
    'com.apple.developer.pass-type-identifiers' => Spaceship::Portal.app_service.passbook,
    # Wireless Accessory Configuration
    'com.apple.external-accessory.wireless-configuration' => Spaceship::Portal.app_service.wireless_accessory
  }

  entitlements ||= {}

  # features = app.details.features
  # services = app.details.enable_services

  entitlements.each_key do |key|
    on_off_app_service = entitlement_on_off_app_service_map[key]
    next unless on_off_app_service

    app = on_off_app_service.on
    log_done("set #{key}: on")
  end

  # Data Protection
  data_protection_value = entitlements['com.apple.developer.default-data-protection'] || ''
  if data_protection_value == 'NSFileProtectionComplete'
    log_done('set com.apple.developer.default-data-protection: complete')
    app = app.update_service(Spaceship::Portal.app_service.data_protection.complete)
  elsif data_protection_value == 'NSFileProtectionCompleteUnlessOpen'
    log_done('set com.apple.developer.default-data-protection: unless_open')
    app = app.update_service(Spaceship::Portal.app_service.data_protection.unless_open)
  elsif data_protection_value == 'NSFileProtectionCompleteUntilFirstUserAuthentication'
    log_done('set com.apple.developer.default-data-protection: until_first_auth')
    app = app.update_service(Spaceship::Portal.app_service.data_protection.until_first_auth)
  end

  # iCloud
  use_icloud_services = false

  # KVS
  use_icloud_services = true if entitlements['com.apple.developer.icloud-container-identifiers']
  use_icloud_services = true if entitlements['com.apple.developer.ubiquity-kvstore-identifier']

  # Documents
  use_icloud_services = true if entitlements['aps-environment']
  use_icloud_services = true if entitlements['com.apple.developer.icloud-container-identifiers']
  use_icloud_services = true if entitlements['com.apple.developer.icloud-services']
  use_icloud_services = true if entitlements['com.apple.developer.ubiquity-container-identifiers']

  # Cloudkit
  use_icloud_services = true if entitlements['aps-environment']
  use_icloud_services = true if entitlements['com.apple.developer.icloud-container-identifiers']
  use_icloud_services = true if entitlements['com.apple.developer.icloud-services']

  if use_icloud_services
    log_warn('app uses iclouzd services, but the step can not automatically enabled them, please do the icloud setup manually')
    app = app.update_service(Spaceship::Portal.app_service.icloud.on)
    app = app.update_service(Spaceship::Portal.app_service.cloud_kit.cloud_kit)
  end

  app
end
