require 'spaceship'
require 'fastlane'

def download_profile(profile, dir)
  tmp_profile_path = File.join(dir, profile.uuid + '.mobileprovision')
  File.write(tmp_profile_path, profile.download)
  tmp_profile_path
end
