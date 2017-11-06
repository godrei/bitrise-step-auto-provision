require 'fastlane'

def sync_app_services(app, entitlements)
  return if entitlements.nil? || entitlements.empty?

  # App Groups
  if entitlements['com.apple.security.application-groups']
    puts 'set app_group: on'
    app = app.update_service(Spaceship::Portal.app_service.app_group.on)
  else
    puts 'set app_group: off'
    app = app.update_service(Spaceship::Portal.app_service.app_group.off)
  end

  # Apple Pay
  if entitlements['com.apple.developer.in-app-payments']
    puts 'set apple_pay: on'
    app = app.update_service(Spaceship::Portal.app_service.apple_pay.on)
  else
    puts 'set apple_pay: off'
    app = app.update_service(Spaceship::Portal.app_service.apple_pay.off)
  end

  # Associated Domains
  if entitlements['com.apple.developer.associated-domains']
    puts 'set associated_domains: on'
    app = app.update_service(Spaceship::Portal.app_service.associated_domains.on)
  else
    puts 'set associated_domains: off'
    app = app.update_service(Spaceship::Portal.app_service.associated_domains.off)
  end

  # Data Protection
  data_protection_value = entitlements['com.apple.developer.default-data-protection']
  if data_protection_value
    case data_protection_value
    when 'NSFileProtectionComplete'
      puts 'set data_protection: complete'
      app = app.update_service(Spaceship::Portal.app_service.data_protection.complete)

    when 'NSFileProtectionCompleteUnlessOpen'
      puts 'set data_protection: unless_open'
      app = app.update_service(Spaceship::Portal.app_service.data_protection.unless_open)

    when 'NSFileProtectionCompleteUntilFirstUserAuthentication'
      puts 'set data_protection: until_first_auth'
      app = app.update_service(Spaceship::Portal.app_service.data_protection.until_first_auth)
    end
  else
    puts 'set data_protection: off'
    app = app.update_service(Spaceship::Portal.app_service.data_protection.off)
  end

  # Game Center
  puts 'set game_center: on'
  app = app.update_service(Spaceship::Portal.app_service.game_center.on)

  # HealthKit
  if entitlements['com.apple.developer.healthkit']
    puts 'set health_kit: on'
    app = app.update_service(Spaceship::Portal.app_service.health_kit.on)
  else
    puts 'set health_kit: off'
    app = app.update_service(Spaceship::Portal.app_service.health_kit.off)
  end

  # HomeKit
  if entitlements['com.apple.developer.homekit']
    puts 'set home_kit: on'
    app = app.update_service(Spaceship::Portal.app_service.home_kit.on)
  else
    puts 'set home_kit: off'
    app = app.update_service(Spaceship::Portal.app_service.home_kit.off)
  end

  # Hotspot
  if entitlements['com.apple.developer.networking.HotspotConfiguration']
    puts 'set hotspot: on'
    app = app.update_service(Spaceship::Portal.app_service.hotspot.on)
  else
    puts 'set hotspot: off'
    app = app.update_service(Spaceship::Portal.app_service.hotspot.off)
  end

  # iCloud
  icould_container_value = entitlements['com.apple.developer.icloud-container-identifiers']
  if icould_container_value
    puts 'set icloud: on'
    app = app.update_service(Spaceship::Portal.app_service.icloud.on)
  end

  icloud_kvs_value = entitlements['com.apple.developer.ubiquity-kvstore-identifier']
  if icloud_kvs_value
    puts 'set icloud: on'
    app = app.update_service(Spaceship::Portal.app_service.icloud.on)
  end

  icould_services_value = entitlements['com.apple.developer.icloud-services']
  if icould_services_value
    case icould_services_value
    when 'CloudDocuments'
      puts 'set cloud_kit: xcode5_compatible'
      app = app.update_service(Spaceship::Portal.app_service.cloud_kit.xcode5_compatible)

    when 'CloudKit'
      puts 'set cloud_kit: cloud_kit'
      app = app.update_service(Spaceship::Portal.app_service.cloud_kit.cloud_kit)
    end
  end

  if icould_container_value.nil? && icloud_kvs_value.nil? && icould_services_value.nil?
    puts 'set icloud: off'
    app = app.update_service(Spaceship::Portal.app_service.icloud.off)
  end

  # In-App Purchase
  if entitlements['com.apple.InAppPurchase']
    puts 'set in_app_purchase: on'
    app = app.update_service(Spaceship::Portal.app_service.in_app_purchase.on)
  else
    puts 'set in_app_purchase: off'
    app = app.update_service(Spaceship::Portal.app_service.in_app_purchase.off)
  end

  # Inter-App Audio
  if entitlements['inter-app-audio']
    puts 'set inter_app_audio: on'
    app = app.update_service(Spaceship::Portal.app_service.inter_app_audio.on)
  else
    puts 'set inter_app_audio: off'
    app = app.update_service(Spaceship::Portal.app_service.inter_app_audio.off)
  end

  # Multipath
  if entitlements['com.apple.developer.networking.multipath']
    puts 'set multipath: on'
    app = app.update_service(Spaceship::Portal.app_service.multipath.on)
  else
    puts 'set multipath: off'
    app = app.update_service(Spaceship::Portal.app_service.multipath.off)
  end

  # Network Extensions
  if entitlements['com.apple.developer.networking.networkextension']
    puts 'set network_extension: on'
    app = app.update_service(Spaceship::Portal.app_service.network_extension.on)
  else
    puts 'set network_extension: off'
    app = app.update_service(Spaceship::Portal.app_service.network_extension.off)
  end

  # NFC Tag Reading
  if entitlements['com.apple.developer.nfc.readersession.formats']
    puts 'set nfc_tag_reading: on'
    app = app.update_service(Spaceship::Portal.app_service.nfc_tag_reading.on)
  else
    puts 'set nfc_tag_reading: off'
    app = app.update_service(Spaceship::Portal.app_service.nfc_tag_reading.off)
  end

  # Personal VPN
  if entitlements['com.apple.developer.networking.vpn.api']
    puts 'set vpn_configuration: on'
    app = app.update_service(Spaceship::Portal.app_service.vpn_configuration.on)
  else
    puts 'set vpn_configuration: off'
    app = app.update_service(Spaceship::Portal.app_service.vpn_configuration.off)
  end

  # Push Notifications
  if entitlements['aps-environment']
    puts 'set push_notification: on'
    app = app.update_service(Spaceship::Portal.app_service.push_notification.on)
  else
    puts 'set push_notification: off'
    app = app.update_service(Spaceship::Portal.app_service.push_notification.off)
  end

  # SiriKit
  if entitlements['com.apple.developer.siri']
    puts 'set siri_kit: on'
    app = app.update_service(Spaceship::Portal.app_service.siri_kit.on)
  else
    puts 'set siri_kit: off'
    app = app.update_service(Spaceship::Portal.app_service.siri_kit.off)
  end

  # Wallet
  if entitlements['com.apple.developer.pass-type-identifiers']
    puts 'set passbook: on'
    app = app.update_service(Spaceship::Portal.app_service.passbook.on)
  else
    puts 'set passbook: off'
    app = app.update_service(Spaceship::Portal.app_service.passbook.off)
  end

  # Wireless Accessory Configuration
  if entitlements['com.apple.external-accessory.wireless-configuration']
    puts 'set wireless_accessory: on'
    app = app.update_service(Spaceship::Portal.app_service.wireless_accessory.on)
  else
    puts 'set wireless_accessory: off'
    app = app.update_service(Spaceship::Portal.app_service.wireless_accessory.off)
  end
end
