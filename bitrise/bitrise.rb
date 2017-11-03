require 'net/http'
require 'uri'

def get_developer_portal_data(build_url, build_api_token)
  url = "#{build_url}/apple_developer_portal_data.json"
  uri = URI.parse(url)

  request = Net::HTTP::Get.new(uri)
  request['BUILD_API_TOKEN'] = build_api_token

  http_object = Net::HTTP.new(uri.host, uri.port)
  http_object.use_ssl = true if uri.scheme == 'https'

  response = http_object.start do |http|
    http.request(request)
  end

  developer_portal_data = JSON.parse(response.body) if response.body

  unless response.code == '200'
    log_debug('')
    log_debug('failed to get developer portal data')
    log_debug("status: #{response.code}")
    log_debug("body: #{response.body}")

    raise developer_portal_data['error_msg'].to_s if developer_portal_data
    raise 'failed to get developer portal data'
  end

  developer_portal_data
end
