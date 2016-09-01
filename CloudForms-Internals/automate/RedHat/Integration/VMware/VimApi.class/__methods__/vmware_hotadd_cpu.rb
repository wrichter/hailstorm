#
# Description: This method is used to modify vCPUs to an existing VM running on VMware
#
# Inputs: $evm.root['vm'], cpus
#

# Get vm object from root
vm = $evm.root['vm']
raise "Missing $evm.root['vm'] object" unless vm

# Get the number of cpus from root
cpus = $evm.root['cpus'].to_i
$evm.log("info", "Detected cpus:<#{cpus}>")

# Add disk to a VM
unless cpus.zero?
  $evm.log("info", "Setting number of vCPUs to #{cpus} on VM:<#{vm.name}>")
  vm.set_number_of_cpus(cpus.to_i, :sync => true)
end
