#
# Description: <Method description here>
#
begin
  prov = $evm.root["miq_provision"]
  prov.set_option(:dialog_param_serviceid, prov.vm.direct_service.id)

  $evm.root.attributes.sort.each { |k, v| $evm.log("info", "Root:<$evm.root> Attribute - #{k}: #{v}")}
  prov.attributes.sort.each { |k, v| $evm.log("info", "prov:<$evm.root['miq_provision']> Attribute - #{k}: #{v}")}

  prov.set_option(:ansiblejob, "/ConfigurationManagement/AnsibleTower/Operations/JobTemplate/dummy_osp.yml")
  $evm.root['wolfram_ansiblejob'] = "/ConfigurationManagement/AnsibleTower/Operations/JobTemplate/dummy_osp.yml"
  $evm.root['ae_result'] = 'ok'
  
rescue => err
  $evm.log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  $evm.root['ae_result'] = 'error'
end
