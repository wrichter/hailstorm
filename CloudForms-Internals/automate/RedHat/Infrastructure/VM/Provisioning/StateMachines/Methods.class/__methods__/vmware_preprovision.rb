#
# Description: This default method is used to apply PreProvision customizations for VMware
#

def log(level, msg, update_message = false)
  $evm.log(level, "#{msg}")
  $evm.root['miq_provision'].message = "#{msg}" if $evm.root['miq_provision'] && update_message
end

def process_customization(prov)
  # Choose the sections to process
  set_vlan          = false
  set_folder        = true
  set_resource_pool = false
  set_notes         = true

  # Get information from the template platform
  template = prov.vm_template
  ems = template.ext_management_system
  product  = template.operating_system['product_name'].downcase
  bitness = template.operating_system['bitness']
  log(:info, "Template:<#{template.name}> Provider:<#{ems.name}> Vendor:<#{template.vendor}> Product:<#{product}> Bitness:<#{bitness}>")

  tags = prov.get_tags
  log(:info, "Provision Tags:<#{tags.inspect}>")

  if set_vlan
    log(:info, "Processing set_vlan...", true)
    ###################################
    # Was a VLAN selected in dialog?
    # If not you can set one here.
    ###################################
    if prov.get_option(:vlan).nil?
      default_vlan = "VM Network"
      #default_dvs = "portgroup1"

      prov.set_vlan(default_vlan)
      #prov.set_dvs(default_dvs)
      log(:info, "Provisioning object <:vlan> updated with <#{prov.get_option(:vlan)}>")
    end
    log(:info, "Processing set_vlan...Complete", true)
  end

  if set_folder
    log(:info, "Processing set_folder...", true)
    ###################################
    # Drop the VM in the targeted folder if no folder was chosen in the dialog
    # The vCenter folder must exist for the VM to be placed correctly else the
    # VM will placed along with the template
    # Folder starts at the Data Center level
    ###################################
    if prov.get_option(:placement_folder_name).nil?
      datacenter = template.v_owning_datacenter
      vsphere_fully_qualified_folder = "#{datacenter}/Discovered virtual machine"

      # prov.get_folder_paths.each { |key, path| log(:info, "Eligible folders:<#{key.inspect}> - <#{path.inspect}>") }
      prov.set_folder(vsphere_fully_qualified_folder)
      log(:info, "Provisioning object <:placement_folder_name> updated with <#{prov.options[:placement_folder_name].inspect}>")
    else
      log(:info, "Placing VM in folder: <#{prov.options[:placement_folder_name].inspect}>")
    end
    log(:info, "Processing set_folder...Complete", true)
  end

  if set_resource_pool
    log(:info, "Processing set_resource_pool...", true)
    if prov.get_option(:placement_rp_name).nil?
      ############################################
      # Find and set the Resource Pool for a VM:
      ############################################
      default_resource_pool = 'MyResPool'
      respool = prov.eligible_resource_pools.detect { |c| c.name.casecmp(default_resource_pool) == 0 }
      log(:info, "Provisioning object <:placement_rp_name> updated with <#{respool.name.inspect}>")
      prov.set_resource_pool(respool)
    end
    log(:info, "Processing set_resource_pool...Complete", true)
  end

  if set_notes
    log(:info, "Processing set_notes...", true)
    ###################################
    # Set the VM Description and VM Annotations  as follows:
    # The example would allow user input in provisioning dialog "vm_description"
    # to be added to the VM notes
    ###################################
    # Stamp VM with custom description
    unless prov.get_option(:vm_description).nil?
      vmdescription = prov.get_option(:vm_description)
      prov.set_option(:vm_description, vmdescription)
      log(:info, "Provisioning object <:vmdescription> updated with <#{vmdescription}>")
    end

    # Setup VM Annotations
    vm_notes =  "Owner: #{prov.get_option(:owner_first_name)} #{prov.get_option(:owner_last_name)}"
    vm_notes += "\nEmail: #{prov.get_option(:owner_email)}"
    vm_notes += "\nSource: #{template.name}"
    vm_notes += "\nDescription: #{vmdescription}" unless vmdescription.nil?
    prov.set_vm_notes(vm_notes)
    log(:info, "Provisioning object <:vm_notes> updated with <#{vm_notes}>")
  end
  log(:info, "Processing set_notes...Complete", true)
end

# Get provisioning object
prov = $evm.root['miq_provision']
log(:info, "Provision:<#{prov.id}> Request:<#{prov.miq_provision_request.id}> Type:<#{prov.type}>")

process_customization(prov)
