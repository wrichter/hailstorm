#
# Description: Create ServiceNow CMDB Record
#

require 'rest-client'
require 'json'
require 'base64'

def log(level, message)
  method = '----- Create ServiceNow CMDB Record -----'
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
  vm   = prov.vm unless prov.nil?
when 'service_template_provision_task'
  # Added for generic catalogue item scenario
  vm_host_name = $evm.root['service_template_provision_task'].options[:dialog][:dialog_option_0_vm_host_name]
  vm           = $evm.vmdb('vm').find_by_name(vm_host_name)
else
  vm = $evm.root['vm']
end
log(:warn, 'VM object is empty') if vm.nil?

# Extend payload attributes as required
virtual     = $evm.object['virtual']     || true
name        = $evm.object['name']        || vm.name
description = $evm.object['description'] || "CloudForms GUID <#{vm.guid}>"
host_name   = $evm.object['host_name']   || get_virtual_column_value(vm, :hostnames)
cpu_count   = $evm.object['cpu_count']   || get_virtual_column_value(vm, :num_cpu)
memory      = $evm.object['memory']      || get_virtual_column_value(vm, :mem_cpu)
vendor      = $evm.object['vendor']      || vm.vendor

payload = {
  :virtual           => virtual,
  :name              => name,
  :short_description => description,
  :host_name         => host_name,
  :cpu_count         => cpu_count,
  :ram               => memory,
  :vendor            => vendor
}
log(:info, "uri   => #{uri}")
log(:info, "payload => #{payload}")

request = RestClient::Request.new(
  :method  => :post,
  :url     => uri,
  :headers => headers,
  :payload => payload.to_json
)
rest_result = request.execute
log(:info, "Return code <#{rest_result.code}>")

json_parse = JSON.parse(rest_result)
result = json_parse['result']
log(:info, "sys_id => <#{result['sys_id']}>")

# Add sys_id to VM object
vm.custom_set(:servicenow_sys_id, result['sys_id'])
