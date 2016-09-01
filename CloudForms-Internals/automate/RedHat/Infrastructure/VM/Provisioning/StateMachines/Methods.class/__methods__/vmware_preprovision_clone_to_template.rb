#
# Description: This default method is used to apply PreProvision customizations as follows:
# 1. VM Description/Annotations
# 2. Target VC Folder
# 3. Tag Inheritance

set_folder     = true
set_notes      = true
set_tags       = true

# Get provisioning object
prov = $evm.root["miq_provision"]

# Get Provision Type
prov_type = prov.provision_type
$evm.log("info", "Provision Type: <#{prov_type}>")

# Get template
template = prov.vm_template

# Get OS Type from the template platform
product  = template.operating_system['product_name'] rescue ''
$evm.log("info", "Source Product: <#{product}>")

if set_notes
  ###################################
  # Set the VM Description and VM Annotations  as follows:
  # The example would allow user input in provisioning dialog "vm_description"
  # to be added to the VM notes
  ###################################
  # Stamp VM with custom description
  unless prov.get_option(:vm_description).nil?
    vmdescription = prov.get_option(:vm_description)
    prov.set_option(:vm_description, vmdescription)
    $evm.log("info", "Provisioning object <:vmdescription> updated with <#{vmdescription}>")
  end

  # Setup VM Annotations
  vm_notes =  "Owner: #{prov.get_option(:owner_first_name)} #{prov.get_option(:owner_last_name)}"
  vm_notes += "\nEmail: #{prov.get_option(:owner_email)}"
  vm_notes += "\nSource Template: #{prov.vm_template.name}"
  vm_notes += "\nCustom Description: #{vmdescription}" unless vmdescription.nil?
  prov.set_vm_notes(vm_notes)
  $evm.log("info", "Provisioning object <:vm_notes> updated with <#{vm_notes}>")
end

if set_folder
  ###################################
  # Drop the VM in the targeted folder if no folder was chosen in the dialog
  # The VC folder must exist for the VM to be placed correctly else the
  # VM will placed along with the template
  # Folder starts at the Data Center level
  ###################################
  datacenter = template.v_owning_datacenter
  vsphere_fully_qualified_folder = "#{datacenter}/Discovered virtual machine"

  if prov.get_option(:placement_folder_name).nil?
    prov.set_folder(vsphere_fully_qualified_folder)
    $evm.log("info", "Provisioning object <:placement_folder_name> updated with <#{vsphere_fully_qualified_folder}>")
  else
    $evm.log("info", "Placing VM in folder: <#{prov.get_option(:placement_folder_name)}>")
  end
end

if set_tags
  ###################################
  #
  # Inherit parent VM's tags and apply
  # them to the published template
  #
  ###################################

  # List of tag categories to carry over
  tag_categories_to_migrate = %w(environment department location function)

  # Assign variables
  prov_tags = prov.get_tags
  $evm.log("info", "Inspecting Provisioning Tags: <#{prov_tags.inspect}>")
  template_tags = template.tags
  $evm.log("info", "Inspecting Template Tags: <#{template_tags.inspect}>")

  # Loop through each source tag for matching categories
  template_tags.each do |cat_tagname|
    category, tag_value = cat_tagname.split('/')
    $evm.log("info", "Processing Tag Category: <#{category}> Value: <#{tag_value}>")
    next unless tag_categories_to_migrate.include?(category)
    prov.add_tag(category, tag_value)
    $evm.log("info", "Updating Provisioning Tags with Category: <#{category}> Value: <#{tag_value}>")
  end
end
