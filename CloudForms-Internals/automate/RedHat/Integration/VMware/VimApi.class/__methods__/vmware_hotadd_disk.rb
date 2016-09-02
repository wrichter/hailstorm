#
# Description: This method is used to add a new disk to an existing VM running on VMware
#
# Inputs: $evm.root['vm'], size
#

# Get vm object
vm = $evm.root['vm']
raise "Missing $evm.root['vm'] object" unless vm

# Get the size for the new disk from the root object
size = $evm.root['size'].to_i
$evm.log("info", "Detected size:<#{size}>")

# Add disk to a VM
if size.zero?
  $evm.log("error", "Size:<#{size}> invalid")
else
  $evm.log("info", "Creating a new #{size}GB disk on Storage:<#{vm.storage_name}>")
  vm.add_disk("[#{vm.storage_name}]", size * 1024, :sync => true)
end
