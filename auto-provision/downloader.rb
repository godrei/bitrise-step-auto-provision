require 'fastlane'
require 'spaceship'

# Downloads a Provisioning Profile
# @param profile (ProvisioningProfile): Provisioning Profile
# @param dir (String): Destination directory
# @return (Array): Path of the downloaded profile
def download_profile(profile, dir)
  profile_path = File.join(dir, profile.uuid + '.mobileprovision')
  File.write(profile_path, profile.download)
  profile_path
end
