#
# Description: Delete ServiceNow CMDB Record
#

require 'rest-client'
require 'base64'

def log(level, message)
  method = '----- Delete ServiceNow CMDB Record -----'
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

# Grab the VM object
log(:info, "vmdb_object_type => <#{$evm.root['vmdb_object_type']}>")
case $evm.root['vmdb_object_type']
when 'miq_provision'
  prov = $evm.root['miq_provision']
  vm = prov.vm unless prov.nil?
else
  vm = $evm.root['vm']
end
log(:warn, 'VM object is empty') if vm.nil?

sys_id = $evm.object['sys_id'] || vm.custom_get(:servicenow_sys_id)
raise 'ServiceNow sys_id is empty' if sys_id.nil?

uri = "#{uri}/#{sys_id}"
log(:info, "uri => #{uri}")

request = RestClient::Request.new(
  :method  => :delete,
  :url     => uri,
  :headers => headers,
)
rest_result = request.execute
log(:info, "Return code <#{rest_result.code}>")
