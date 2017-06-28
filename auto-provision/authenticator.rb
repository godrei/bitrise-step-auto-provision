require 'fastlane'
require 'spaceship'

def developer_portal_sign_in(username, password, two_factor_session, team_id)
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
