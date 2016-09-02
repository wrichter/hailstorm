#
# Description: Update ServiceNow CMDB Record
#

require 'rest-client'
require 'json'
require 'base64'

def log(level, message)
  method = '----- Update ServiceNow CMDB Record -----'
  $evm.log(level, "#{method} - #{message}")
end

def get_virtual_column_value(vm, virtual_column_name)
  virtual_column_value = vm.send(virtual_column_name)
  return virtual_column_value unless virtual_column_value.nil?
  nil
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

sys_id  = $evm.object['sys_id'] || vm.custom_get(:servicenow_sys_id)
raise 'ServiceNow sys_id is empty' if sys_id.nil?

uri   = "#{uri}/#{sys_id}"

log(:info, 'Getting item details')
request = RestClient::Request.new(
  :method  => :get,
  :url     => uri,
  :headers => headers
)
rest_result = request.execute
log(:info, "Return code <#{rest_result.code}>")

json_parse = JSON.parse(rest_result)
result = json_parse['result']

# Extend payload attributes as required
result[:virtual]           = $evm.object['virtual']     || true
result[:name]              = $evm.object['name']        || vm.name
result[:short_description] = $evm.object['description'] || "CloudForms GUID <#{vm.guid}>"
result[:host_name]         = $evm.object['host_name']   || get_virtual_column_value(vm, :hostnames)
result[:cpu_count]         = $evm.object['cpu_count']   || get_virtual_column_value(vm, :num_cpu)
result[:ram]               = $evm.object['memory']      || get_virtual_column_value(vm, :mem_cpu)
result[:vendor]            = $evm.object['vendor']      || vm.vendor
log(:info, "payload => #{result}")

log(:info, 'Updating record details')
request = RestClient::Request.new(
  :method  => :put,
  :url     => uri,
  :headers => (headers.merge!(:cookies => request.cookies)),
  :payload => result.to_json
)
rest_result = request.execute
log(:info, "Return code <#{rest_result.code}>")
