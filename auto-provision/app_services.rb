require 'fastlane'

def sync_app_services(app, entitlements)
  entitlements = {} if entitlements.to_a.empty?

  # features = app.details.features
  # services = app.details.enable_services

  # App Groups
  if entitlements['com.apple.security.application-groups']
    log_done('set app_group: on')
    app = app.update_service(Spaceship::Portal.app_service.app_group.on)
  else
    log_done('set app_group: off')
    app = app.update_service(Spaceship::Portal.app_service.app_group.off)
  end

  # Apple Pay
  if entitlements['com.apple.developer.in-app-payments']
    log_done('set apple_pay: on')
    app = app.update_service(Spaceship::Portal.app_service.apple_pay.on)
  else
    log_done('set apple_pay: off')
    app = app.update_service(Spaceship::Portal.app_service.apple_pay.off)
  end

  # Associated Domains
  if entitlements['com.apple.developer.associated-domains']
    log_done('set associated_domains: on')
    app = app.update_service(Spaceship::Portal.app_service.associated_domains.on)
  else
    log_done('set associated_domains: off')
    app = app.update_service(Spaceship::Portal.app_service.associated_domains.off)
  end

  # Data Protection
  data_protection_value = entitlements['com.apple.developer.default-data-protection']
  if data_protection_value
    case data_protection_value
    when 'NSFileProtectionComplete'
      log_done('set data_protection: complete')
      app = app.update_service(Spaceship::Portal.app_service.data_protection.complete)

    when 'NSFileProtectionCompleteUnlessOpen'
      log_done('set data_protection: unless_open')
      app = app.update_service(Spaceship::Portal.app_service.data_protection.unless_open)

    when 'NSFileProtectionCompleteUntilFirstUserAuthentication'
      log_done('set data_protection: until_first_auth')
      app = app.update_service(Spaceship::Portal.app_service.data_protection.until_first_auth)
    end
  else
    log_done('set data_protection: off')
    app = app.update_service(Spaceship::Portal.app_service.data_protection.off)
  end

  # Game Center
  # log_done('set game_center: on')
  # app = app.update_service(Spaceship::Portal.app_service.game_center.on)

  # HealthKit
  if entitlements['com.apple.developer.healthkit']
    log_done('set health_kit: on')
    app = app.update_service(Spaceship::Portal.app_service.health_kit.on)
  else
    log_done('set health_kit: off')
    app = app.update_service(Spaceship::Portal.app_service.health_kit.off)
  end

  # HomeKit
  if entitlements['com.apple.developer.homekit']
    log_done('set home_kit: on')
    app = app.update_service(Spaceship::Portal.app_service.home_kit.on)
  else
    log_done('set home_kit: off')
    app = app.update_service(Spaceship::Portal.app_service.home_kit.off)
  end

  # Hotspot
  if entitlements['com.apple.developer.networking.HotspotConfiguration']
    log_done('set hotspot: on')
    app = app.update_service(Spaceship::Portal.app_service.hotspot.on)
  else
    log_done('set hotspot: off')
    app = app.update_service(Spaceship::Portal.app_service.hotspot.off)
  end

  # iCloud
  icould_container_value = entitlements['com.apple.developer.icloud-container-identifiers']
  if icould_container_value
    log_done('set icloud: on')
    app = app.update_service(Spaceship::Portal.app_service.icloud.on)

    log_done('set cloud_kit: cloud_kit')
    app = app.update_service(Spaceship::Portal.app_service.cloud_kit.cloud_kit)
  end

  icloud_kvs_value = entitlements['com.apple.developer.ubiquity-kvstore-identifier']
  if icloud_kvs_value
    log_done('set icloud: on')
    app = app.update_service(Spaceship::Portal.app_service.icloud.on)

    log_done('set cloud_kit: cloud_kit')
    app = app.update_service(Spaceship::Portal.app_service.cloud_kit.cloud_kit)
  end

  icould_services_value = entitlements['com.apple.developer.icloud-services']
  if icould_services_value
    case icould_services_value
    when 'CloudDocuments'
      log_done('set cloud_kit: xcode5_compatible')
      app = app.update_service(Spaceship::Portal.app_service.cloud_kit.xcode5_compatible)

    when 'CloudKit'
      log_done('set cloud_kit: cloud_kit')
      app = app.update_service(Spaceship::Portal.app_service.cloud_kit.cloud_kit)
    end
  end

  if icould_container_value.nil? && icloud_kvs_value.nil? && icould_services_value.nil?
    log_done('set icloud: off')
    app = app.update_service(Spaceship::Portal.app_service.icloud.off)
  end

  # In-App Purchase
  if entitlements['com.apple.InAppPurchase']
    log_done('set in_app_purchase: on')
    app = app.update_service(Spaceship::Portal.app_service.in_app_purchase.on)
  else
    log_done('set in_app_purchase: off')
    app = app.update_service(Spaceship::Portal.app_service.in_app_purchase.off)
  end

  # Inter-App Audio
  if entitlements['inter-app-audio']
    log_done('set inter_app_audio: on')
    app = app.update_service(Spaceship::Portal.app_service.inter_app_audio.on)
  else
    log_done('set inter_app_audio: off')
    app = app.update_service(Spaceship::Portal.app_service.inter_app_audio.off)
  end

  # Multipath
  if entitlements['com.apple.developer.networking.multipath']
    log_done('set multipath: on')
    app = app.update_service(Spaceship::Portal.app_service.multipath.on)
  else
    log_done('set multipath: off')
    app = app.update_service(Spaceship::Portal.app_service.multipath.off)
  end

  # Network Extensions
  if entitlements['com.apple.developer.networking.networkextension']
    log_done('set network_extension: on')
    app = app.update_service(Spaceship::Portal.app_service.network_extension.on)
  else
    log_done('set network_extension: off')
    app = app.update_service(Spaceship::Portal.app_service.network_extension.off)
  end

  # NFC Tag Reading
  if entitlements['com.apple.developer.nfc.readersession.formats']
    log_done('set nfc_tag_reading: on')
    app = app.update_service(Spaceship::Portal.app_service.nfc_tag_reading.on)
  else
    log_done('set nfc_tag_reading: off')
    app = app.update_service(Spaceship::Portal.app_service.nfc_tag_reading.off)
  end

  # Personal VPN
  if entitlements['com.apple.developer.networking.vpn.api']
    log_done('set vpn_configuration: on')
    app = app.update_service(Spaceship::Portal.app_service.vpn_configuration.on)
  else
    log_done('set vpn_configuration: off')
    app = app.update_service(Spaceship::Portal.app_service.vpn_configuration.off)
  end

  # Push Notifications
  if entitlements['aps-environment']
    log_done('set push_notification: on')
    app = app.update_service(Spaceship::Portal.app_service.push_notification.on)
  else
    log_done('set push_notification: off')
    app = app.update_service(Spaceship::Portal.app_service.push_notification.off)
  end

  # SiriKit
  if entitlements['com.apple.developer.siri']
    log_done('set siri_kit: on')
    app = app.update_service(Spaceship::Portal.app_service.siri_kit.on)
  else
    log_done('set siri_kit: off')
    app = app.update_service(Spaceship::Portal.app_service.siri_kit.off)
  end

  # Wallet
  if entitlements['com.apple.developer.pass-type-identifiers']
    log_done('set passbook: on')
    app = app.update_service(Spaceship::Portal.app_service.passbook.on)
  else
    log_done('set passbook: off')
    app = app.update_service(Spaceship::Portal.app_service.passbook.off)
  end

  # Wireless Accessory Configuration
  if entitlements['com.apple.external-accessory.wireless-configuration']
    log_done('set wireless_accessory: on')
    app = app.update_service(Spaceship::Portal.app_service.wireless_accessory.on)
  else
    log_done('set wireless_accessory: off')
    app = app.update_service(Spaceship::Portal.app_service.wireless_accessory.off)
  end

  app
end
