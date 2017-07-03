require 'fastlane'
require 'spaceship'

# Authenticate user on Apple Developer Portal
# @param username (String): Apple Developer Portal user name
# @param password (String): Apple Developer Portal password
# @param two_factor_session (String) (Optional): 2FA session token
# @param team_id (String) (Optional): Development team to sign in
def developer_portal_authentication(username, password, two_factor_session = nil, team_id = nil)
  ENV['FASTLANE_PASSWORD'] = password
  ENV['FASTLANE_SESSION'] = two_factor_session unless two_factor_session.to_s.empty?

  client = Spaceship::Portal.login(username, password)

  if team_id.to_s.empty?
    teams = client.teams

    raise 'your account belongs to multiple teams, please provide the team id to sign in' if teams.to_a.size > 1
  else
    client.team_id = team_id
  end
end
