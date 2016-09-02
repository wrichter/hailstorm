#
# Description: Get All ServiceNow CMDB Records
#

require 'rest-client'
require 'json'
require 'base64'

def log(level, message)
  method = '----- Get All ServiceNow CMDB Records -----'
  $evm.log(level, "#{method} - #{message}")
end

snow_server   = $evm.object['snow_server']
snow_user     = $evm.object['snow_user']
snow_password = $evm.object.decrypt('snow_password')
table_name    = $evm.object['table_name']
uri           = "https://#{snow_server}/api/now/table/#{table_name}"

headers = {
  :content_type  => 'application/json',
  :accept        => 'application/json',
  :authorization => "Basic #{Base64.strict_encode64("#{snow_user}:#{snow_password}")}"
}

log(:info, "uri => #{uri}")

request = RestClient::Request.new(
  :method  => :get,
  :url     => uri,
  :headers => headers
)
rest_result = request.execute
log(:info, "Return code <#{rest_result.code}>")

json_parse = JSON.parse(rest_result)
result = json_parse['result']
result.each do | ci |
  log(:info, "Item <#{ci['name']}> attributes:")
  ci.sort.each do | k, v |
    log(:info, "    #{k} => <#{v}>")
  end
end
