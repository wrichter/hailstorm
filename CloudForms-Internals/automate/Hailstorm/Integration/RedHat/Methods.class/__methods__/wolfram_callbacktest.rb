#
# Description: <Method description here>
#
$evm.root.attributes.sort.each { |k, v| $evm.log("info", "Root:<$evm.root> Attribute - #{k}: #{v}")}
$evm.object.attributes.sort.each { |k, v| $evm.log("info", "<$evm.object> Attribute - #{k}: #{v}")}
$automation = $evm.object['automation_task']
$automation.attributes.sort.each { |k, v| $evm.log("info", "<$automation_task> Attribute - #{k}: #{v}")}
$evm.log("info", $automation.options.inspect)
$evm.log("info", $automation.options[:attrs][:serviceid])
$automation.options[:attrs].each { |k, v| $evm.log("info", "automation - options Attribute - #{k}: #{v}")}
$service = $evm.vmdb(:service).find_by id: $automation.options[:attrs][:serviceid]
#$service.custom_set "Hallo","Welt!"
$automation.options[:attrs].each { |k, v| 
  $service.custom_set "#{k}","#{v}" 
 }
