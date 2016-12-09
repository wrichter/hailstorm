#----------------------------------------------------------------
#
# CFME Automate Method: start_vm
#
# Author: Peter McGowan (Red Hat)
#
#----------------------------------------------------------------
begin
  vm = $evm.root['miq_provision'].destination
  $evm.log(:info, "Current VM power state = #{vm.power_state}")
  unless vm.power_state == 'on'
    vm.start
    vm.refresh
    $evm.root['ae_result'] = 'retry'
    $evm.root['ae_retry_interval'] = '30.seconds'
  else
    $evm.root['ae_result'] = 'ok'
  end
  
rescue => err
  $evm.log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  $evm.root['ae_result'] = 'error'
end
