require 'net/http'
require 'uri'

def get_developer_portal_data(build_url, build_api_token)
  url_str = "#{build_url}/apple_developer_portal_data"
  puts "url_str: #{url_str}"
  uri = URI.parse(url_str)

  request = Net::HTTP::Get.new(uri)
  request['BUILD_API_TOKEN'] = build_api_token

  response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
    http.request(request)
  end

  response
end
