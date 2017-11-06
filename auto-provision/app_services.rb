require 'fastlane'

def update_app_services(app, entitlements)
  return if entitlements.nil? || entitlements.empty?

  entitlements.each do |entitlement_key, entitlement_value|
    case entitlement_key

    when 'com.apple.security.application-groups'
      puts "found #{entitlement_key}"
      puts "set app_group: on"
      app.update_service(Spaceship::Portal.app_service.app_group.on)

    when 'com.apple.developer.in-app-payments'
      puts "found #{entitlement_key}"
      puts "set apple_pay: on"
      app.update_service(Spaceship::Portal.app_service.apple_pay.on)

    when 'com.apple.developer.associated-domains'
      puts "found #{entitlement_key}"
      puts "set associated_domains: on"
      app.update_service(Spaceship::Portal.app_service.associated_domains.on)

    when 'com.apple.developer.default-data-protection'
      case entitlement_value
      when 'NSFileProtectionComplete'
        puts "found #{entitlement_key}"
        puts "set data_protection: complete"
        app.update_service(Spaceship::Portal.app_service.data_protection.complete)

      when 'NSFileProtectionCompleteUnlessOpen'
        puts "found #{entitlement_key}"
        puts "set data_protection: unless_open"
        app.update_service(Spaceship::Portal.app_service.data_protection.unless_open)

      when 'NSFileProtectionCompleteUntilFirstUserAuthentication'
        puts "found #{entitlement_key}"
        puts "set data_protection: until_first_auth"
        app.update_service(Spaceship::Portal.app_service.data_protection.until_first_auth)
      end

    when 'com.apple.developer.healthkit'
      puts "found #{entitlement_key}"
      puts "set health_kit: on"
      app.update_service(Spaceship::Portal.app_service.health_kit.on)

    when 'com.apple.developer.homekit'
      puts "found #{entitlement_key}"
      puts "set home_kit: on"
      app.update_service(Spaceship::Portal.app_service.home_kit.on)

    when 'com.apple.external-accessory.wireless-configuration'
      puts "found #{entitlement_key}"
      puts "set wireless_accessory: on"
      app.update_service(Spaceship::Portal.app_service.wireless_accessory.on)

    when 'com.apple.developer.icloud-container-identifiers'
      puts "found #{entitlement_key}"
      puts "app service depends on another entitlements key"

    when 'com.apple.developer.ubiquity-kvstore-identifier'
      puts "found #{entitlement_key}"
      puts "set icloud: on"
      app.update_service(Spaceship::Portal.app_service.icloud.on)

    when 'com.apple.developer.icloud-services'
      case entitlement_value
      when 'CloudDocuments'
        puts "found #{entitlement_key}"
        puts "set cloud_kit: xcode5_compatible"
        app.update_service(Spaceship::Portal.app_service.cloud_kit.xcode5_compatible)

      when 'CloudKit'
        puts "found #{entitlement_key}"
        puts "set cloud_kit: cloud_kit"
        app.update_service(Spaceship::Portal.app_service.cloud_kit.cloud_kit)

      end
    when 'com.apple.InAppPurchase'
      puts "found #{entitlement_key}"
      puts "set in_app_purchase: on"
      app.update_service(Spaceship::Portal.app_service.in_app_purchase.on)

    when 'inter-app-audio'
      puts "found #{entitlement_key}"
      puts "set inter_app_audio: on"
      app.update_service(Spaceship::Portal.app_service.inter_app_audio.on)

    when 'com.apple.developer.pass-type-identifiers'
      puts "found #{entitlement_key}"
      puts "set passbook: on"
      app.update_service(Spaceship::Portal.app_service.passbook.on)

    when 'aps-environment'
      puts "found #{entitlement_key}"
      puts "set push_notification: on"
      app.update_service(Spaceship::Portal.app_service.push_notification.on)

    when 'com.apple.developer.siri'
      puts "found #{entitlement_key}"
      puts "set siri_kit: on"
      app.update_service(Spaceship::Portal.app_service.siri_kit.on)

    when 'com.apple.developer.networking.vpn.api'
      puts "found #{entitlement_key}"
      puts "set vpn_configuration: on"
      app.update_service(Spaceship::Portal.app_service.vpn_configuration.on)

    when 'com.apple.developer.networking.networkextension'
      puts "found #{entitlement_key}"
      puts "set network_extension: on"
      app.update_service(Spaceship::Portal.app_service.network_extension.on)

    when 'com.apple.developer.networking.HotspotConfiguration'
      puts "found #{entitlement_key}"
      puts "set hotspot: on"
      app.update_service(Spaceship::Portal.app_service.hotspot.on)

    when 'com.apple.developer.networking.multipath'
      puts "found #{entitlement_key}"
      puts "set multipath: on"
      app.update_service(Spaceship::Portal.app_service.multipath.on)

    when 'com.apple.developer.nfc.readersession.formats'
      puts "found #{entitlement_key}"
      puts "set nfc_tag_reading: on"
      app.update_service(Spaceship::Portal.app_service.nfc_tag_reading.on)

    else 
      puts "UNKOWN key: #{entitlement_key}"
    end
  end
end

# def update_app_services(project_or_workspace_path, app)
#   project_paths = contained_projects(project_or_workspace_path)
#   project_paths.each do |project_path|
#     project = Xcodeproj::Project.open(project_path)
#     project.targets.each do |target|
#       next if target.test_target_type?

#       # find the target, which matches to to the app
#       bundle_id_match = false

#       target.build_configuration_list.build_configurations.each do |build_configuration|
#         build_settings = build_configuration.build_settings

#         bundle_identifier = build_settings['PRODUCT_BUNDLE_IDENTIFIER']

#         if bundle_identifier == app.bundle_id
#           bundle_id_match = true
#           break
#         end
#       end

#       next unless bundle_id_match

#       attributes = project.root_object.attributes['TargetAttributes']
#       target_attributes = attributes[target.uuid]
#       target_capabilities = target_attributes['SystemCapabilities']

#       next unless target_capabilities

#       $capability_helpers.each do |helper|
#         capabilty_name = helper[:name]

#         # check if capability set
#         required_capability = helper[:system_capabilities]
#         result = target_capabilities[required_capability]

#         next unless result
#         next unless result['enabled'].to_s == '1'

#         helper[:function].call(app)
#         log_details "capability (#{capabilty_name}) set"
#       end
#     end
#   end

#   app
# end

###
# backup
#  remove this, once capability handling works
###

# app_groups = {
#   name: 'App Groups',
#   function: proc { |app| app.update_service(Spaceship::Portal.app_service.app_group.on) },
#   system_capabilities: 'com.apple.ApplicationGroups.iOS',
#   entitlements: {
#     key: 'com.apple.security.application-groups',
#     value: '' # array
#   },
# }

# apple_pay = {
#   name: 'Apple Pay',
#   function: proc { |app| app.update_service(Spaceship::Portal.app_service.apple_pay.on) },
#   system_capabilities: 'com.apple.ApplePay',
#   entitlements: {
#     key: 'com.apple.developer.in-app-payments',
#     value: '' # array
#   },
# }

# associated_domains = {
#   name: 'Associated Domains',
#   function: proc { |app| app.update_service(Spaceship::Portal.app_service.associated_domains.on) },
#   system_capabilities: 'com.apple.SafariKeychain',
#   entitlements: {
#     key: 'com.apple.developer.associated-domains',
#     value: '' # array
#   },
# }

# data_protection_complete = {
#   name: 'Data Protection - Complete Protection',
#   function: proc { |app| app.update_service(Spaceship::Portal.app_service.data_protection.complete) },
#   system_capabilities: 'com.apple.DataProtection',
#   entitlements: {
#     key: 'com.apple.developer.default-data-protection',
#     value: 'NSFileProtectionComplete' # string
#   },
# }

# data_protection_unless_open = {
#   name: 'Data Protection - Protected Unless Open',
#   function: proc { |app| app.update_service(Spaceship::Portal.app_service.data_protection.unless_open) },
#   system_capabilities: 'com.apple.DataProtection',
#   entitlements: {
#     key: 'com.apple.developer.default-data-protection',
#     value: 'NSFileProtectionCompleteUnlessOpen' # string
#   },
# }

# data_protection_until_first_auth = {
#   name: 'Data Protection - Protected Until First User Authentication',
#   function: proc { |app| app.update_service(Spaceship::Portal.app_service.data_protection.until_first_auth) },
#   system_capabilities: 'com.apple.DataProtection',
#   entitlements: {
#     key: 'com.apple.developer.default-data-protection',
#     value: 'NSFileProtectionCompleteUntilFirstUserAuthentication' # string
#   },
# }

# game_center = {
#   name: 'Game Center',
#   function: proc { |app| app.update_service(Spaceship::Portal.app_service.game_center.on) },
#   default: true,
#   system_capabilities: 'com.apple.GameCenter',
#   info_plist: {
#     key: 'UIRequiredDeviceCapabilities',
#     value: 'gamekit'
#   },
# }

# health_kit = {
#   name: 'HealthKit',
#   function: proc { |app| app.update_service(Spaceship::Portal.app_service.health_kit.on) },
#   system_capabilities: 'com.apple.HealthKit',
#   entitlements: {
#     key: 'com.apple.developer.healthkit',
#     value: 'true' # bool
#   },
#   info_plist: {
#     key: 'UIRequiredDeviceCapabilities',
#     value: 'healthkit' # array
#   },
# }

# home_kit = {
#   name: 'HomeKit',
#   function: proc { |app| app.update_service(Spaceship::Portal.app_service.home_kit.on) },
#   system_capabilities: 'com.apple.HomeKit',
#   entitlements: {
#     key: 'com.apple.developer.homekit',
#     value: 'true' # bool
#   },
# }

# icloud_key_value_storage = {
#   name: 'iCloud - Compatible with Xcode 5',
#   function: proc { |app| app.update_service(Spaceship::Portal.app_service.icloud.on) },
#   system_capabilities: 'com.apple.iCloud',
#   entitlements: {
#     key: 'com.apple.developer.ubiquity-kvstore-identifier',
#     value: '' # string, not empty
#   },
# }

# icloud_documents = {
#   name: 'iCloud - Compatible with Xcode 5',
#   function: proc { |app| app.update_service(Spaceship::Portal.app_service.icloud.on) },
#   system_capabilities: 'com.apple.iCloud',
#   entitlements: {
#     key: 'com.apple.developer.icloud-services',
#     value: 'CloudDocuments' # array
#   },
# }

# icloud_cloud_kit = {
#   name: 'iCloud - Include CloudKit support (requires Xcode 6 )',
#   function: proc { |app| app.update_service(Spaceship::Portal.app_service.cloud_kit.cloud_kit) },
#   system_capabilities: 'com.apple.iCloud',
#   entitlements: {
#     key: 'com.apple.developer.icloud-services',
#     value: 'CloudKit' # array
#   },
# }

# in_app_purchase = {
#   name: 'In-App Purchase',
#   function: proc { |app| app.update_service(Spaceship::Portal.app_service.in_app_purchase.on) },
#   default: true,
#   system_capabilities: 'com.apple.InAppPurchase',
# }

# inter_app_audio = {
#   name: 'Inter-App Audio',
#   function: proc { |app| app.update_service(Spaceship::Portal.app_service.inter_app_audio.on) },
#   system_capabilities: 'com.apple.InterAppAudio',
#   entitlements: {
#     key: 'inter-app-audio',
#     value: 'true' # bool
#   },
# }

# personal_vpn = {
#   name: 'Personal VPN',
#   function: proc { |app| app.update_service(Spaceship::Portal.app_service.vpn_configuration.on) },
#   system_capabilities: 'com.apple.VPNLite',
#   entitlements: {
#     key: 'com.apple.developer.networking.vpn.api',
#     value: 'allow-vpn' # array
#   },
# }

# push = {
#   name: 'Push Notifications',
#   function: proc { |app| app.update_service(Spaceship::Portal.app_service.push_notification.on) },
#   system_capabilities: 'com.apple.Push',
#   entitlements: {
#     key: 'aps-environment',
#     value: '' # string (development/?)
#   },
# }

# siri = {
#   name: 'SiriKit',
#   function: proc { |app| app.update_service(Spaceship::Portal.app_service.siri_kit.on) },
#   system_capabilities: 'com.apple.Siri',
#   entitlements: {
#     key: 'com.apple.developer.siri',
#     value: '' # bool, true
#   },
# }

# wallet_all_team_pass_type = {
#   name: 'Wallet',
#   function: proc { |app| app.update_service(Spaceship::Portal.app_service.passbook.on) },
#   system_capabilities: 'com.apple.Wallet',
#   entitlements: {
#     key: 'com.apple.developer.pass-type-identifiers',
#     value: '' # array, not empty
#   },
# }

# wireless_accessory_configuration = {
#   name: 'Wireless Accessory Configuration',
#   function: proc { |app| app.update_service(Spaceship::Portal.app_service.wireless_accessory.on) },
#   system_capabilities: 'com.apple.WAC',
#   entitlements: {
#     key: 'com.apple.external-accessory.wireless-configuration',
#     value: 'true' # bool
#   },
# }

# # not presented in Developer Portal
# maps = {
#   system_capabilities: 'com.apple.Maps.iOS'
# }

# # missing
# network_extension = {
#   entitlements: {
#     key: 'com.apple.developer.networking.networkextension',
#     value: '' # array, not empty
#   },
#   system_capabilities: 'com.apple.NetworkExtensions'
# }

# # not presented in Developer Portal
# background_modes = {
#   info_plist: {
#     key: 'UIBackgroundModes',
#     value: '' # array
#   },
#   system_capabilities: 'com.apple.BackgroundModes'
# }

# # not presented in Developer Portal
# keychain_sharing = {
#   entitlements: {
#     key: 'keychain-access-groups',
#     value: '' # array, not empty
#   },
#   system_capabilities: 'com.apple.Keychain'
# }
