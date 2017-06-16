require 'spaceship'
require 'fastlane'

require_relative 'log'

WILDCARD_APP_BUNDLE_ID = '*'.freeze
WILDCARD_APP_NAME = 'Bitrise Wildcard'.freeze
PROVISIONIN_PROFILE_NAME = 'Bitrise iOS Provisioning Profile: *'.freeze

# Params - Authentication

username = ENV['apple_developer_portal_user']
password = ENV['apple_developer_portal_password']
team_id = ENV['apple_developer_portal_team_id']
passcode = ENV['apple_developer_portal_passcode']

puts "username: #{username}"
puts "password: #{password}"
puts "team_id: #{team_id}"
puts "passcode: #{passcode}"

# ---

# Authentication

log_info('Authentication')

ENV['FASTLANE_PASSWORD'] = password

output, status = Open3.capture2("fastlane spaceauth -u #{username}", :stdin_data => passcode)
puts "output: #{output}"
puts "status: #{status}"

client = Spaceship::Portal.login(username, password)
client.team_id = team_id

# ---

# Find or create app with wildcard bundle id

log_info("Seraching for app with wildcard bundle id (#{WILDCARD_APP_BUNDLE_ID})")

app = Spaceship::Portal.app.find(WILDCARD_APP_BUNDLE_ID)

if app.nil?
  log_warning("No app with wildcard bundle id found, generating with name: #{WILDCARD_APP_NAME} ...")

  app = Spaceship::Portal.app.create!(bundle_id: bundle_id, name: WILDCARD_APP_NAME)

  raise 'No app generated' if app.nil?
end

log_details(app.to_s)

# ---

# Find or create development cretificate

log_info('Searching for development certificate')

dev_cert = nil

dev_certs = Spaceship::Portal.certificate.development.all

if dev_certs.empty?
  log_warning('No development certificate found, generating ...')

  csr, pkey = Spaceship::Portal.certificate.create_certificate_signing_request
  dev_cert = Spaceship::Portal.certificate.development.create!(csr: csr)

  raise 'No certificate generated' if app.nil?
else
  if dev_certs.count > 1
    log_warning('Multiple development certificate found, using first:')
    dev_certs.each_with_index { |cert, index| puts "#{index}, #{cert}" }
  end

  dev_cert = dev_certs.first
end

log_details(dev_cert.to_s)

# ---

# Find or create provisioning profile

log_info('Searching for development provisioning profile')

profile_dev = nil

profiles_dev = Spaceship::Portal.provisioning_profile.development.all

if profiles_dev.empty?
  log_warning('No development provisioning profile found, generating ...')

  profile_dev = Spaceship::Portal.provisioning_profile.development.create!(bundle_id: WILDCARD_APP_BUNDLE_ID, certificate: dev_cert, name: PROVISIONIN_PROFILE_NAME)
else
  if profiles_dev.count > 1
    log_warning('Multiple development provisionig profile found, using first:')
    profiles_dev.each_with_index { |prof, index| puts "#{index}, #{prof}" }
  end

  profile_dev = profiles_dev.first
end

log_details(profile_dev.to_s)

# ---

log_info('Git clone sample')

system('rm -rf ./_tmp')
system('git clone https://github.com/godrei/sign_test.git ./_tmp')

log_info('Build sample app')

system('xcodebuild -project ./_tmp/sign_test.xcodeproj -scheme sign_test archive')