#
# Description: This default method is used to apply PreProvision customizations for RHEV provisioning
#

def log(level, msg, update_message = false)
  $evm.log(level, "#{msg}")
  $evm.root['miq_provision'].message = "#{msg}" if $evm.root['miq_provision'] && update_message
end

def process_customization(prov)
  # Choose the sections to process
  set_vlan  = true
  set_notes = true

  # Get information from the template platform
  template = prov.vm_template
  product  = template.operating_system['product_name'].downcase
  log(:info, "Template:<#{template.name}> Vendor:<#{template.vendor}> Product:<#{product}>")

  if set_vlan
    # Set default VLAN here if one was not chosen in the dialog?
    default_vlan = "rhevm"

    if prov.get_option(:vlan).nil?
      prov.set_vlan(default_vlan)
      log(:info, "Provisioning object <:vlan> updated with <#{default_vlan}>")
    end
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
    vm_notes += "\nSource Template: #{template.name}"
    vm_notes += "\nCustom Description: #{vmdescription}" unless vmdescription.nil?
    prov.set_vm_notes(vm_notes)
    log(:info, "Provisioning object <:vm_notes> updated with <#{vm_notes}>")
    log(:info, "Processing set_notes...Complete", true)
  end
end

# Get provisioning object
prov = $evm.root['miq_provision']
log(:info, "Provision:<#{prov.id}> Request:<#{prov.miq_provision_request.id}> Type:<#{prov.type}>")

process_customization(prov)
