#
# Description: This method is used to modify vRAM to an existing VM running on VMware
#
# Inputs: $evm.root['vm'], ram
#

# Get vm object from root
vm = $evm.root['vm']
raise "Missing $evm.root['vm'] object" unless vm

# Get amount of ram from root
ram = $evm.root['ram'].to_i
$evm.log("info", "Detected ram:<#{ram}>")

unless ram.zero?
  $evm.log("info", "Setting amount of vRAM to #{ram} on VM:<#{vm.name}>")
  vm.set_memory(ram, :sync => true)
end
