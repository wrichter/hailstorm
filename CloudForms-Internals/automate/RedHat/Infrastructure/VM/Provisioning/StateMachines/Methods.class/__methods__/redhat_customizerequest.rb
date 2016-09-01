#
# Description: This method is used to Customize the Provisioning Request
# Customization Template mapping for RHEV, RHEV PXE, and RHEV ISO provisioning
#

def log(level, msg, update_message=false)
  $evm.log(level, "#{msg}")
  $evm.root['miq_provision'].message = "#{msg}" if $evm.root['miq_provision'] && update_message
end

def set_customspec(prov, spec)
  prov.set_customization_spec(spec, true) rescue nil
  log(:info, "Provisioning object updated {:sysprep_custom_spec => #{prov.get_option(:sysprep_custom_spec).inspect rescue nil}}")
  log(:info, "Provisioning object updated {:sysprep_spec_override => #{prov.get_option(:sysprep_spec_override)}}")
end

def process_redhat_pxe(mapping, prov, template, product, provider)
  case mapping

  when 0
    # No mapping

  when 1
    if product.include?("windows")
      # find the windows image that matches the template name if a PXE Image was NOT chosen in the dialog
      if prov.get_option(:pxe_image_id).nil?

        log(:info, "Inspecting prov.eligible_windows_images: #{prov.eligible_windows_images.inspect}")
        pxe_image = prov.eligible_windows_images.detect { |pi| pi.name.casecmp(template.name)==0 }
        if pxe_image.nil?
          log(:error, "Failed to find matching PXE Image", true)
          raise
        else
          log(:info, "Found matching Windows PXE Image ID: #{pxe_image.id} Name: #{pxe_image.name} Description: #{pxe_image.description}")
        end
        prov.set_windows_image(pxe_image)
        log(:info, "Provisioning object updated {:pxe_image_id => #{prov.get_option(:pxe_image_id).inspect}}")
      end
      # Find the first customization template that matches the template name if none was chosen in the dialog
      if prov.get_option(:customization_template_id).nil?
        log(:info, "Inspecting Eligible Customization Templates: #{prov.eligible_customization_templates.inspect}")
        cust_temp = prov.eligible_customization_templates.detect { |ct| ct.name.casecmp(template.name)==0 }
        if cust_temp.nil?
          log(:error, "Failed to find matching PXE Image", true)
          raise
        end
        log(:info, "Found mathcing Windows Customization Template ID: #{cust_temp.id} Name: #{cust_temp.name} Description: #{cust_temp.description}")
        prov.set_customization_template(cust_temp)
        log(:info, "Provisioning object updated {:customization_template_id => #{prov.get_option(:customization_template_id).inspect}}")
      end
    else
      # find the first PXE Image that matches the template name if NOT chosen in the dialog
      if prov.get_option(:pxe_image_id).nil?
        pxe_image = prov.eligible_pxe_images.detect { |pi| pi.name.casecmp(template.name)==0 }
        log(:info, "Found Linux PXE Image ID: #{pxe_image.id} Name: #{pxe_image.name} Description: #{pxe_image.description}")
        prov.set_pxe_image(pxe_image)
        log(:info, "Provisioning object updated {:pxe_image_id => #{prov.get_option(:pxe_image_id).inspect}}")
      end
      # Find the first Customization Template that matches the template name if NOT chosen in the dialog
      if prov.get_option(:customization_template_id).nil?
        cust_temp = prov.eligible_customization_templates.detect { |ct| ct.name.casecmp(template.name)==0 }
        log(:info, "Found Customization Template ID: #{cust_temp.id} Name: #{cust_temp.name} Description: #{cust_temp.description}")
        prov.set_customization_template(cust_temp)
        log(:info, "Provisioning object updated {:customization_template_id => #{prov.get_option(:customization_template_id).inspect}}")
      end
    end
  when 3
    #
    # Enter your own RHEV custom mapping here
  else
    # Skip mapping
  end # end case
end # end process_redhat

# process_redhat_iso - mapping customization templates (ks.cfg)
def process_redhat_iso(mapping, prov, template, product, provider)
  case mapping

  when 0
    # No mapping
  when 1
    if product.include?("windows")
      # Linux Support only for now
    else
      # Linux - Find the first ISO Image that matches the template name if NOT chosen in the dialog
      if prov.get_option(:iso_image_id).nil?
        log(:info, "Inspecting prov.eligible_iso_images: #{prov.eligible_iso_images.inspect rescue nil}")
        iso_image = prov.eligible_iso_images.detect { |iso| iso.name.casecmp(template.name)==0 }
        if iso_image.nil?
          log(:error, "Failed to find matching ISO Image", true)
          raise
        else
          log(:info, "Found Linux ISO Image ID: #{iso_image.id} Name: #{iso_image.name} Description: #{iso_image.description}")
          prov.set_iso_image(iso_image)
          log(:info, "Provisioning object updated {:iso_image_id => #{prov.get_option(:iso_image_id).inspect}}")
        end
      else
        log(:info, "ISO Image selected from dialog: #{prov.get_option(:iso_image_id).inspect}")
      end

      # Find the first Customization Template that matches the template name if NOT chosen in the dialog
      if prov.get_option(:customization_template_id).nil?
        log(:info, "prov.eligible_customization_templates: #{prov.eligible_customization_templates.inspect}")

        cust_temp = $evm.vmdb('customization_template').all.detect { |ct| ct.name.casecmp(template.name)==0 }
        if cust_temp.nil?
          log(:error, "Failed to find matching Customization Template", true)
          raise
        else
          log(:info, "Found Customization Template ID: #{cust_temp.id} Name: #{cust_temp.name} Description: #{cust_temp.description}")
          prov.set_customization_template(cust_temp)
          log(:info, "Provisioning object updated {:customization_template_id => #{prov.get_option(:customization_template_id).inspect}}")
        end
      else
        log(:info, "Customization Template selected from dialog: #{prov.get_option(:customization_template_id).inspect}")
      end
    end
  when 2
    #
    # Enter your own RHEV ISO custom mapping here
  else
    # Skip mapping
  end
end

# process_redhat - mapping cloud-init templates
def process_redhat(mapping, prov, template, product, provider)
  log(:info, "Processing process_redhat...", true)
  case mapping
  when 0
    # No mapping
  when 1
    if prov.get_option(:customization_template_id).nil?
      customization_template_search_by_ws_values = ws_values[:customization_template] rescue nil
      customization_template_search_by_template_name = template.name
      log(:info, "prov.eligible_customization_templates: #{prov.eligible_customization_templates.inspect}")
      customization_template = nil

      unless customization_template_search_by_template_name.nil?
        # Search for customization templates enabled for Cloud-Init that match the template/image name
        if customization_template.blank?
          log(:info, "Searching for customization templates enabled for (Cloud-Init) that are named: #{customization_template_search_by_template_name}")
          customization_template = prov.eligible_customization_templates.detect { |ct| ct.name.casecmp(template.name)==0 }
        end
      end
      unless customization_template_search_by_ws_values.nil?
        # Search for customization templates enabled for Cloud-Init that match ws_values[:customization_template]
        if customization_template.blank?
          log(:info, "Searching for customization templates enabled for (Cloud-Init) that are named: #{customization_template_search_by_ws_values}")
          customization_template = prov.eligible_customization_templates.detect { |ct| ct.name.casecmp(customization_template_search_by_ws_values)==0 }
        end
      end
      if customization_template.blank?
        log(:warn, "Failed to find matching Customization Template", true)
      else
        log(:info, "Found Customization Template ID: #{customization_template.id} Name: #{customization_template.name} Description: #{customization_template.description}")
        prov.set_customization_template(customization_template) rescue nil
        log(:info, "Provisioning object updated {:customization_template_id => #{prov.get_option(:customization_template_id).inspect}}")
        log(:info, "Provisioning object updated {:customization_template_script => #{prov.get_option(:customization_template_script).inspect}}")
      end
    else
      log(:info, "Customization Template selected form dialog ID: #{prov.get_option(:customization_template_id).inspect}} Script: #{prov.get_option(:customization_template_script).inspect}")
    end
  when 2
    # Enter your own RHEV custom mapping here
  else
    # Skip mapping
  end
  log(:info, "Processing process_redhat...Complete", true)
end

# Get provisioning object
prov = $evm.root["miq_provision"]

log(:info, "Provision:<#{prov.id}> Request:<#{prov.miq_provision_request.id}> Type:<#{prov.type}>")

template = prov.vm_template
provider = template.ext_management_system
product  = template.operating_system['product_name'].downcase rescue nil
log(:info, "Template: #{template.name} Provider: #{provider.name} Vendor: #{template.vendor} Product: #{product}")

# Build case statement to determine which type of processing is required
case prov.type

when 'MiqProvisionRedhat'
  ##########################################################
  # Red Hat Mapping for template Provisioning
  #
  # Possible values:
  #   0 - (DEFAULT No Mapping) This option skips the mapping of customization templates/cloud-init
  #
  ##########################################################
  mapping = 0
  process_redhat(mapping, prov, template, product, provider)

when 'MiqProvisionRedhatViaIso'
  ##########################################################
  # Red Hat Customization Template Mapping for ISO Provisioning
  #
  # Possible values:
  #   0 - (DEFAULT No Mapping) This option skips the mapping of iso images and customization templates
  #
  #   1 - CFME will look for a iso image and a customization template with
  #   the exact name as the template name if none were chosen from the provisioning dialog
  #
  #   2 - Include your own custom mapping logic here
  ##########################################################
  mapping = 0
  process_redhat_iso(mapping, prov, template, product, provider)

when 'MiqProvisionRedhatViaPxe'
  ##########################################################
  # Red Hat Customization Template Mapping for PXE Provisioning
  #
  # Possible values:
  #   0 - (DEFAULT No Mapping) This option skips the mapping of pxe images and customization templates
  #
  #   1 - CFME will look for a pxe image and a customization template with
  #   the exact name as the template name if none were chosen from the provisioning dialog
  #
  #   2 - Include your own custom mapping logic here
  ##########################################################
  mapping = 0
  process_redhat_pxe(mapping, prov, template, product, provider)

else
  log(:info, "Provisioning Type: #{prov.type} does not match, skipping processing")
end
